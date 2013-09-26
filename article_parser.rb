require 'rubygems'
require 'stanford-core-nlp'
require 'debugger'

load 'heapster.rb'
load 'lib/document_manager.rb'

StanfordCoreNLP.jar_path = "/Users/mwest/Documents/code/stanford-core-nlp/"
StanfordCoreNLP.model_path = "/Users/mwest/Documents/code/stanford-core-nlp/"

DOC_BASE_PATH = 'docs'

documents = DocumentManager.new(DOC_BASE_PATH)
documents.scan

pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :pos, :lemma, :parse, :ner, :dcoref)
TokenFrequency = Struct.new(:token, :frequency)
documents.unprocessed_docs.each do |file|
  puts "Processing file #{file.path}..."
  text = file.contents.join('')

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

f = File.open('output.txt', 'w')
documents.each do |name, metadata|
  f.write "Computing TF.IDF for #{name}..\n."

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

  tokens = Set.new
  5.times do
    next_tokens = inverted_index[highest_scorers.pop_root]
    next_tokens.each {|t| tokens.add(t)}
  end

  f.write "Highest scorers: #{tokens.to_a.join(', ')}\n"
end
f.close
puts "Done..."
