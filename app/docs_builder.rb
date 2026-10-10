require 'fileutils'
require 'logger'
require 'open3'
require 'tmpdir'

class CommandRunner
  def run!(command, chdir: nil)
    options = chdir ? { chdir: chdir } : {}
    return if system(*command, **options)

    raise "Command failed: #{command.join(' ')}"
  end

  def capture!(command, chdir: nil)
    options = chdir ? { chdir: chdir } : {}
    stdout, stderr, status = Open3.capture3(*command, **options)
    raise "Command failed: #{command.join(' ')}: #{stderr.strip}" unless status.success?

    stdout.strip
  end
end

class DocsBuilder
  DEFAULT_REPOSITORY_URL = 'https://github.com/SpeciesFileGroup/taxonworks.git'.freeze
  DEFAULT_REF = 'development'.freeze
  QUEUED_MESSAGE = 'Rebuild request queued! Once processed docs will be updated.'.freeze

  def initialize(
    sinatra_settings,
    repository_url: ENV.fetch('TAXONWORKS_REPOSITORY_URL', DEFAULT_REPOSITORY_URL),
    ref: ENV.fetch('TAXONWORKS_REF', DEFAULT_REF),
    docs_root: ENV.fetch('DOCS_ROOT', File.expand_path('../var', __dir__)),
    logger: Logger.new($stdout),
    command_runner: CommandRunner.new,
    yardoc: nil
  )
    @settings = sinatra_settings
    @repository_url = repository_url
    @ref = ref
    @docs_root = File.expand_path(docs_root)
    @work_root = File.join(@docs_root, 'work')
    @releases_root = File.join(@docs_root, 'releases')
    @logger = logger
    @command_runner = command_runner
    @yardoc = yardoc
    @rebuild_queue = SizedQueue.new(1)
    @rebuild_mutex = Mutex.new
    @worker = nil

    FileUtils.mkdir_p([@work_root, @releases_root])
  end

  def start
    return if @worker&.alive?

    @worker = Thread.new do
      loop do
        @rebuild_queue.pop
        rebuild
      rescue StandardError => error
        @logger.error("Documentation rebuild failed: #{error.class}: #{error.message}")
      end
    end
  end

  def rebuild
    @rebuild_mutex.synchronize { perform_rebuild }
  end

  def queue
    @rebuild_queue.push(true, true)
    @logger.info('Documentation rebuild queued')
    QUEUED_MESSAGE
  rescue ThreadError
    @logger.info('Documentation rebuild request coalesced with a pending rebuild')
    QUEUED_MESSAGE
  end

  private

  def perform_rebuild
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    source_dir = Dir.mktmpdir('taxonworks-', @work_root)
    docs_dir = Dir.mktmpdir('docs-', @releases_root)
    published = false

    @logger.info("Building documentation from #{@repository_url} ref #{@ref}")
    clone(source_dir)
    commit = current_commit(source_dir)
    generate_docs(source_dir, docs_dir)
    verify_docs!(docs_dir)
    publish(docs_dir)
    published = true

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    @logger.info(format('Published TaxonWorks documentation for %s in %.1f seconds', commit, duration))
    docs_dir
  ensure
    FileUtils.rm_rf(source_dir) if source_dir
    FileUtils.rm_rf(docs_dir) if docs_dir && !published
  end

  def clone(source_dir)
    # Dir.mktmpdir creates the directory, while git clone expects its target not
    # to exist. Removing this unique empty directory keeps all paths controlled.
    Dir.rmdir(source_dir)
    @command_runner.run!([
      'git', 'clone', '--depth', '1', '--single-branch', '--branch', @ref,
      @repository_url, source_dir
    ])
  end

  def current_commit(source_dir)
    @command_runner.capture!(%w[git rev-parse HEAD], chdir: source_dir)
  end

  def generate_docs(source_dir, docs_dir)
    @yardoc ||= Gem.bin_path('yard', 'yardoc')
    @command_runner.run!([@yardoc, '-o', docs_dir, '--no-save'], chdir: source_dir)
  end

  def verify_docs!(docs_dir)
    index = File.join(docs_dir, 'index.html')
    raise 'YARD completed without producing index.html' unless File.file?(index)
  end

  def publish(docs_dir)
    previous = @settings.public_folder
    @settings.public_folder = docs_dir
    FileUtils.rm_rf(previous) if managed_release?(previous) && previous != docs_dir
  end

  def managed_release?(path)
    return false unless path

    expanded = File.expand_path(path)
    expanded.start_with?("#{@releases_root}#{File::SEPARATOR}")
  end
end
