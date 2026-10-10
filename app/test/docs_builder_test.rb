require 'minitest/autorun'
require 'tmpdir'
require 'timeout'
require_relative '../docs_builder'

class FakeSettings
  attr_accessor :public_folder
end

class FakeCommandRunner
  attr_reader :clone_count, :generation_attempts

  def initialize
    @clone_count = 0
    @generation_attempts = 0
    @generation_failures = 0
  end

  def fail_next_generation!
    @generation_failures += 1
  end

  def run!(command, chdir: nil)
    if command.first == 'git'
      @clone_count += 1
      FileUtils.mkdir_p(command.last)
    else
      @generation_attempts += 1
      if @generation_failures.positive?
        @generation_failures -= 1
        raise 'simulated YARD failure'
      end

      output_index = command.index('-o') + 1
      FileUtils.mkdir_p(command[output_index])
      File.write(File.join(command[output_index], 'index.html'), 'documentation')
    end
  end

  def capture!(command, chdir: nil)
    '0123456789abcdef'
  end
end

class DocsBuilderTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('docs-builder-test-')
    @settings = FakeSettings.new
    @runner = FakeCommandRunner.new
    @logger = Logger.new(File::NULL)
    @builder = DocsBuilder.new(
      @settings,
      docs_root: @tmpdir,
      logger: @logger,
      command_runner: @runner,
      yardoc: 'yardoc'
    )
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_successful_rebuild_publishes_docs_and_cleans_source
    published = @builder.rebuild

    assert_equal published, @settings.public_folder
    assert File.file?(File.join(published, 'index.html'))
    assert_empty Dir.children(File.join(@tmpdir, 'work'))
  end

  def test_failed_rebuild_preserves_previous_docs_and_cleans_partial_output
    previous = @builder.rebuild
    @runner.fail_next_generation!

    assert_raises(RuntimeError) { @builder.rebuild }
    assert_equal previous, @settings.public_folder
    assert File.file?(File.join(previous, 'index.html'))
    assert_equal [File.basename(previous)], Dir.children(File.join(@tmpdir, 'releases'))
    assert_empty Dir.children(File.join(@tmpdir, 'work'))
  end

  def test_successful_rebuild_removes_superseded_release
    previous = @builder.rebuild
    current = @builder.rebuild

    refute_equal previous, current
    refute File.exist?(previous)
    assert File.file?(File.join(current, 'index.html'))
  end

  def test_queue_coalesces_when_one_rebuild_is_already_pending
    assert_equal DocsBuilder::QUEUED_MESSAGE, @builder.queue
    assert_equal DocsBuilder::QUEUED_MESSAGE, @builder.queue
    assert_equal 1, @builder.instance_variable_get(:@rebuild_queue).size
  end

  def test_worker_continues_after_a_failed_rebuild
    @runner.fail_next_generation!
    @builder.start
    @builder.queue
    wait_until { @runner.generation_attempts == 1 }

    @builder.queue
    wait_until { @settings.public_folder }

    assert_equal 2, @runner.generation_attempts
    assert File.file?(File.join(@settings.public_folder, 'index.html'))
  end

  private

  def wait_until(&condition)
    Timeout.timeout(2) do
      sleep 0.01 until condition.call
    end
  end
end
