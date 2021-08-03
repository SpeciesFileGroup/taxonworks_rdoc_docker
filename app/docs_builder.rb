class DocsBuilder
  def initialize(sinatra_settings)
    @settings = sinatra_settings
    @rebuild_queue = Queue.new

    Thread.new do
      while @rebuild_queue.pop
        @rebuild_queue.pop while @rebuild_queue.size > 0
        rebuild
      end
    end    
  end

  def rebuild
    time = DateTime.now.iso8601
    tw_dir = File.expand_path("taxonworks/#{time}")
    doc_dir = File.expand_path("public/#{time}")

    raise "Failed to fetch code" unless system("git clone https://github.com/SpeciesFileGroup/taxonworks.git --depth 1 #{tw_dir}")
    FileUtils.mkdir(doc_dir)

    if system("cd '#{tw_dir}' && yardoc -o '#{doc_dir}' --no-save")
      old, @settings.public_folder = @settings.public_folder, doc_dir
      FileUtils.rm_rf(old) if old
    end

    FileUtils.rm_r(tw_dir)    
  end

  def queue
    @rebuild_queue << true
    'Rebuild request queued! Once processed docs will be updated.'
  end
end