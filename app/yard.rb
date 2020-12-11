module Yard
  def self.rebuild(settings)
    time = DateTime.now.iso8601
    tw_dir = File.expand_path("taxonworks/#{time}")
    doc_dir = File.expand_path("public/#{time}")

    raise "Failed to fetch code" unless system("git clone https://github.com/SpeciesFileGroup/taxonworks.git --depth 1 #{tw_dir}")
    FileUtils.mkdir(doc_dir)

    if system("yardoc taxonworks -o #{doc_dir} --no-save")
      old, settings.public_folder = settings.public_folder, doc_dir
      FileUtils.rm_rf(old) if old
    end

    FileUtils.rm_r(tw_dir)    
  end
end