#!/usr/bin/env ruby
require 'sinatra'
require 'fileutils'
require 'thread'
require_relative 'docs_builder'

builder = DocsBuilder.new(settings)

get("/rebuild/#{ENV['REBUILD_TOKEN']}") { builder.queue }
post("/rebuild/#{ENV['REBUILD_TOKEN']}") { builder.queue }

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

not_found do
  '404'
end

settings.public_folder = nil
builder.rebuild
