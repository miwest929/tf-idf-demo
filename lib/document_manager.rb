class Document
  attr_accessor :path, :base_name, :type

  BASE_NAME_REGEX = /.*\/(.*)\.(.*)/

  def initialize(path)
    @path = path

    parts = self.parse(path)
    @base_name = parts[:base_name]
    @type = parts[:type]
  end

  def text?
    @type == 'txt'
  end

  def freq?
    @type == 'freq'
  end

  def contents
    IO.readlines(@path)
  end
protected
  def parse(path)
    file_match = path.match(BASE_NAME_REGEX)

    {base_name: file_match[1], type: file_match[2]}
  end
end

class DocumentManager
  attr_accessor :content_files, :freq_files
  attr_accessor :base_path

  BASE_NAME_REGEX = /.*\/(.*)\.(.*)/

  TokenFrequency = Struct.new(:token, :frequency)

  def initialize(base_path)
    @base_path =  base_path
    @content_files = Set.new
    @freq_files = Set.new
  end

  def add(file)
    doc = Document.new(file)

    if doc.text?
      @content_files.add(doc)
    elsif doc.freq?
      @freq_files.add(doc)
    end
  end

  def docs
    @content_files
  end

  def unprocessed_docs
    files = @freq_files.map {|f| f.path}
    docs.reject {|f| files.include?(f.path)}
  end

  def write_freq_file(file, token_frequency)
    tokens = token_frequency.map { |k,v| TokenFrequency.new(k, v) }
    tokens.sort_by! {|i| i.frequency}

    file = File.open("#{file.path}.freq", 'w')
    tokens.each do |t|
      file.write("#{t.frequency}      #{t.token}\n")
    end
    file.close

    @freq_files.add(file)
  end

  def scan
    Dir["#{@base_path}/*"].select { |e| File.file?(e) }.each do |name|
      self.add(name)
    end
  end
end
