#!/usr/bin/env ruby
require 'sinatra'
require_relative 'docs_builder'

rebuild_token = ENV.fetch('REBUILD_TOKEN', '').strip
abort 'REBUILD_TOKEN must be set and must not be empty' if rebuild_token.empty?

set :bind, '0.0.0.0'
set :environment, :production
set :port, ENV.fetch('PORT', '4567').to_i
set :public_folder, nil
set :server, :puma

builder = DocsBuilder.new(settings)
builder.rebuild
builder.start

get("/rebuild/#{rebuild_token}") { builder.queue }
post("/rebuild/#{rebuild_token}") { builder.queue }

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

not_found do
  '404'
end
