require 'sinatra'
require 'json'
load 'lib/document_manager.rb'

# Set port that sinatra uses
set :port, 9494

get '/documents' do
  manager = DocumentManager.new('docs')
  manager.scan

  documents = []
  doc_id = 1
  manager.docs.each do |d|
    documents << {
      id: doc_id,
      title: d.base_name,
      contents: d.contents
    }

    doc_id += 1
  end

  JSON.generate({documents: documents})
end
