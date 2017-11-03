require 'sinatra'
require 'active_support'
require 'active_support/all'
require 'http'
require 'json'
require 'yaml'

class TreeMap
  def search(params)
    JSON.parse(HTTP.get("https://www.gov.uk/api/search.json?#{params.to_param}"))
  end

  def to_csv
    output = [
      "id,value",
      "govuk",
      "govuk.not-part-of-job-story-type"
    ]

    uncategorised.each do |document_type|
      output << "govuk.not-part-of-job-story-type.#{document_type},#{document_type_counts[document_type]}"
    end

    supertypes["user_need_document_supertype"]["items"].each do |supertype|
      output << "govuk.#{supertype["id"]}"

      supertype["document_types"].each do |document_type|
        output << "govuk.#{supertype["id"]}.#{document_type},#{document_type_counts[document_type]}"
      end
    end

    output.join("\n")
  end

  def document_type_counts
    @counts ||= begin
      hash = {}
      query = search(facet_content_store_document_type: 100)
      query["facets"]["content_store_document_type"]["options"].each do |o|
        hash[o["value"]["slug"]] = o["documents"]
      end
      hash
    end
  end

  def supertypes
    @supertypes ||= YAML.load(HTTP.get("https://raw.githubusercontent.com/alphagov/govuk_document_types/add-super-type/data/supertypes.yml"))
  end

  def uncategorised
    categorised = supertypes["user_need_document_supertype"]["items"].map { |supertype| supertype["document_types"] }.flatten
    document_type_counts.keys - categorised
  end
end

get '/' do
  erb :index
end

get '/treemap.csv' do
  content_type :text
  map = TreeMap.new
  map.to_csv
end
