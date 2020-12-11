#!/usr/bin/env ruby
require 'sinatra'
require 'fileutils'
require 'thread'
require_relative 'yard'

rebuild_queue = Queue.new

get "/rebuild/#{ENV['REBUILD_TOKEN']}" do
  rebuild_queue << true
  'Rebuild request queued! Once processed docs will be updated.'
end

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

not_found do
  '404'
end

Thread.new do
  while rebuild_queue.pop
    rebuild_queue.pop while rebuild_queue.size > 0
    Yard.rebuild(settings)
  end
end

settings.public_folder = nil
Yard.rebuild(settings)
