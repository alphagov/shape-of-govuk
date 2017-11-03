require 'sinatra'
require 'active_support'
require 'active_support/all'
require 'http'
require 'json'
require 'yaml'

class TreeMap
  attr_reader :document_supertype

  def initialize(document_supertype:)
    @document_supertype = document_supertype
  end

  def search(params)
    JSON.parse(HTTP.get("https://www.gov.uk/api/search.json?#{params.to_param}"))
  end

  def to_csv
    output = [
      "id,value",
      "govuk",
      "govuk.missing_document_type,#{missing_count}",
      "govuk.#{other}",
    ]

    uncategorised.each do |document_type|
      output << "govuk.#{other}.#{document_type},#{document_type_counts[document_type]}"
    end

    supertypes[document_supertype]["items"].each do |supertype|
      output << "govuk.#{supertype["id"]}"

      supertype["document_types"].each do |document_type|
        output << "govuk.#{supertype["id"]}.#{document_type},#{document_type_counts[document_type]}"
      end
    end

    output.join("\n")
  end

  def other
    supertypes[document_supertype]["default"]
  end

  def document_type_counts
    @counts ||= begin
      hash = {}
      facet_query["facets"]["content_store_document_type"]["options"].each do |o|
        hash[o["value"]["slug"]] = o["documents"]
      end
      hash
    end
  end

  def missing_count
    facet_query["facets"]["content_store_document_type"]["documents_with_no_value"]
  end

  def facet_query
    @facet_query ||= search(facet_content_store_document_type: 100)
  end

  def supertypes
    @supertypes ||= YAML.load(HTTP.get("https://raw.githubusercontent.com/alphagov/govuk_document_types/add-super-type/data/supertypes.yml"))
  end

  def uncategorised
    categorised = supertypes[document_supertype]["items"].map { |supertype| supertype["document_types"] }.flatten
    document_type_counts.keys - categorised
  end
end

get '/' do
  unless params[:supertype]
    redirect '?supertype=user_need_document_supertype'
  end

  map = TreeMap.new(document_supertype: params[:supertype])
  erb :index, locals: { map: map }
end

get '/treemap.csv' do
  content_type :text
  map = TreeMap.new(document_supertype: params[:supertype])
  map.to_csv
end
