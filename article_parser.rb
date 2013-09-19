require 'rubygems'
require 'stanford-core-nlp'
require 'debugger'

StanfordCoreNLP.jar_path = "/Users/mwest/Documents/code/stanford-core-nlp/"
StanfordCoreNLP.model_path = "/Users/mwest/Documents/code/stanford-core-nlp/"

DOC_BASE_PATH = 'docs'
BASE_NAME_REGEX = /.*\/(.*)\.(.*)/
content_files = Set.new
Dir["#{DOC_BASE_PATH}/*"].select { |e| File.file?(e) }.each do |name|
  file_match = name.match(BASE_NAME_REGEX)

  base_name = file_match[1]
  type = file_match[2]

  content_files.add(name) if type == 'txt'
end

pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :pos, :lemma, :parse, :ner, :dcoref)
TokenFrequency = Struct.new(:token, :frequency)
content_files.each do |f|
  puts "Processing file #{f}..."
  text = IO.readlines(f).join('')

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

  tokens = term_frequency.map { |k,v| TokenFrequency.new(k, v) }
  tokens.sort_by! {|i| i.frequency}

  file = File.open("#{f}.freq", 'w')
  puts "Writing to '#{f}.freq'. Total of #{tokens.count} tokens..."
  tokens.each do |t|
    file.write("#{t.frequency}      #{t.token}\n")
  end
  file.close
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

  max_score = -1
  highest_scorers = []
  metadata.token_freq.each do |t, f|
    tf = f.to_f / metadata.most_freq
    idf = Math.log(documents.count / document_counts[t].to_f, 2)

    tf_idf = tf * idf
    if tf_idf > max_score
      max_score = tf_idf
      highest_scorers << t
    end
  end

  puts "Highest scorers: #{highest_scorers.join(', ')}"
end

puts "Done..."
