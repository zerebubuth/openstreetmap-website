# The NodeController is the RESTful interface to Node objects

class NodeController < ApplicationController
  require "xml/libxml"
  require "cgimap_ext"
  include CgimapExt

  skip_before_action :verify_authenticity_token
  before_action :authorize, :only => [:create, :update, :delete]
  before_action :require_allow_write_api, :only => [:create, :update, :delete]
  before_action :require_public_data, :only => [:create, :update, :delete]
  before_action :check_api_writable, :only => [:create, :update, :delete]
  before_action :check_api_readable, :except => [:create, :update, :delete]
  around_action :api_call_handle_error, :api_call_timeout

  # Create a node from XML.
  def create
    assert_method :put

    node = Node.from_xml(request.raw_post, true)

    # Assume that Node.from_xml has thrown an exception if there is an error parsing the xml
    node.create_with_history @user
    render :text => node.id.to_s, :content_type => "text/plain"
  end

  # Dump the details on a node given in params[:id]
  def read
    cgimap_handle_response(request)
  end

  # Update a node from given XML
  def update
    node = Node.find(params[:id])
    new_node = Node.from_xml(request.raw_post)

    unless new_node && new_node.id == node.id
      fail OSM::APIBadUserInput.new("The id in the url (#{node.id}) is not the same as provided in the xml (#{new_node.id})")
    end

    node.update_from(new_node, @user)
    render :text => node.version.to_s, :content_type => "text/plain"
  end

  # Delete a node. Doesn't actually delete it, but retains its history
  # in a wiki-like way. We therefore treat it like an update, so the delete
  # method returns the new version number.
  def delete
    node = Node.find(params[:id])
    new_node = Node.from_xml(request.raw_post)

    unless new_node && new_node.id == node.id
      fail OSM::APIBadUserInput.new("The id in the url (#{node.id}) is not the same as provided in the xml (#{new_node.id})")
    end
    node.delete_with_history!(new_node, @user)
    render :text => node.version.to_s, :content_type => "text/plain"
  end

  # Dump the details on many nodes whose ids are given in the "nodes" parameter.
  def nodes
    unless params["nodes"]
      fail OSM::APIBadUserInput.new("The parameter nodes is required, and must be of the form nodes=id[,id[,id...]]")
    end

    ids = params["nodes"].split(",").collect(&:to_i)

    if ids.length == 0
      fail OSM::APIBadUserInput.new("No nodes were given to search for")
    end
    doc = OSM::API.new.get_xml_doc

    Node.find(ids).each do |node|
      doc.root << node.to_xml_node
    end

    render :text => doc.to_s, :content_type => "text/xml"
  end
end
