require 'rubygems'
require 'stanford-core-nlp'
require 'debugger'

load 'heapster.rb'

StanfordCoreNLP.jar_path = "/Users/mwest/Documents/code/stanford-core-nlp/"
StanfordCoreNLP.model_path = "/Users/mwest/Documents/code/stanford-core-nlp/"

DOC_BASE_PATH = 'docs'

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
    file_match = file.match(BASE_NAME_REGEX)

    base_name = file_match[1]
    type = file_match[2]

    if type == 'txt'
      @content_files.add(base_name)
    elsif type == 'freq'
      @freq_files.add(base_name)
    end
  end

  def docs
    @content_files.map {|f| "#{f}.txt" }.reject {|f| @freq_files.include?(f)}
  end

  def contents(file)
    IO.readlines("#{@base_path}/#{file}")
  end

  def write_freq_file(file, token_frequency)
    tokens = token_frequency.map { |k,v| TokenFrequency.new(k, v) }
    tokens.sort_by! {|i| i.frequency}

    file = File.open("#{@base_path}/#{file}.freq", 'w')
    tokens.each do |t|
      file.write("#{t.frequency}      #{t.token}\n")
    end
    file.close

    @freq_files.add(file)
  end

private
end

documents = DocumentManager.new(DOC_BASE_PATH)
Dir["#{DOC_BASE_PATH}/*"].select { |e| File.file?(e) }.each do |name|
  documents.add(name)
end

pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :pos, :lemma, :parse, :ner, :dcoref)
TokenFrequency = Struct.new(:token, :frequency)
documents.docs.each do |file|
  puts "Processing file #{file}..."
  text = documents.contents(file).join('')

  text = StanfordCoreNLP::Annotation.new(text)
  pipeline.annotate(text)

  term_frequency = {}

  text.get(:sentences).each do |sentence|
    sentence.get(:tokens).each do |token|
      token_value = token.get(:value).to_s.downcase
      current_freq = term_frequency[token_value]
      term_frequency[token_value] = current_freq ? current_freq+1 : 1
    end
  end

  puts "Writing to '#{file}.freq'. Total of #{term_frequency.keys.count} tokens..."
  documents.write_freq_file(file, term_frequency)
end

puts "Collect frequencies and compute most important words for each document..."
DocumentMetadata = Struct.new(:token_freq, :most_freq)
documents = {}
document_counts = {}
Dir["#{DOC_BASE_PATH}/*.freq"].each do |file|
  puts "Processing #{file} freq file..."

  metadata = DocumentMetadata.new({}, 0)
  IO.readlines(file).each do |line|
    freq, token = line.split(' ')

    freq = freq.to_i
    metadata.token_freq[token] = freq

    current_doc_count = document_counts[token]
    document_counts[token] = current_doc_count ? current_doc_count+1 : 1

    metadata.most_freq = freq if freq > metadata.most_freq
  end
  documents[file] = metadata
end

documents.each do |name, metadata|
  puts "Computing TF.IDF for #{name}..."

  highest_scorers = Heap.new(:max)
  inverted_index = {}
  metadata.token_freq.each do |t, f|
    tf = f.to_f / metadata.most_freq
    idf = Math.log(documents.count / document_counts[t].to_f, 2)

    tf_idf = tf * idf
    highest_scorers.insert(tf_idf)

    if inverted_index[tf_idf]
      inverted_index[tf_idf] << t
    else
      inverted_index[tf_idf] = [t]
    end
  end

  print "Highest scorers: "
  tokens = Set.new
  5.times do
    next_tokens = inverted_index[highest_scorers.pop_root]
    next_tokens.each {|t| tokens.add(t)}
  end

  tokens.each {|t| print "#{t}, "}
  puts ''
end

puts "Done..."
