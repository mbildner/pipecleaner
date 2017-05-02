require 'yaml'
require 'json'

class PipelineScanner
  def initialize(pipeline_name, pipeline_path, concourse, lpass, secrets_parser)
    @pipeline_name = pipeline_name
    @pipeline_path = pipeline_path
    @concourse = concourse
    @lpass = lpass
    @secrets_parser = secrets_parser
  end

  def scan_for_leaks
    jobs.map do |job_name|
      build_id = concourse.last_successful_build(job_name)
      log = concourse.logs(job_name, build_id)
      lpass_notes.map do |note|
        note[:note].map do |k, v|
          if log.include?(v)
            {
                pipeline: pipeline_name,
                job: job_name,
                build: build_id,
                key: k,
                note: note[:name]
            }
          end
        end
      end
    end.flatten.compact
  end

  private

  attr_reader :pipeline_name, :pipeline_path, :concourse, :lpass, :secrets_parser

  def lpass_notes
    @_lpass_notes ||= secrets_parser.parse(File.read(pipeline_path))
        .map {|note_name| {name: note_name, note: lpass.note(note_name)}}
  end

  def jobs
    concourse.pipeline(pipeline_name).fetch('jobs').map {|job| job['name']}
  end

end

class PipelineSecretParser
  def initialize; end

  def parse(definition_text)
    definition_text.scan(/\({2}(.+)\){2}/)
        .map(&:first)
        .map {|full_note_path| full_note_path.split('/Notes/')[0]}
  end
end

class LpassWrapper
  def initialize;
  end

  def note(name)
    YAML.safe_load(`lpass show --notes "#{name}"`)
  end
end

class ConcourseWrapper
  def initialize(pipeline_name, fly_target)
    @pipeline_name = pipeline_name
    @fly_target = fly_target
  end

  def pipeline(name)
    YAML.safe_load(`fly -t #{fly_target} get-pipeline -p #{name}`)
  end

  def builds(job_name)
    `fly -t #{fly_target} builds -j #{pipeline_name}/#{job_name}`.split("\n")
  end

  def logs(job, build_number)
    `fly -t #{fly_target} watch -j #{pipeline_name}/#{job} -b #{build_number}`
  end

  def last_successful_build(job_name)
    builds(job_name).find do |job|
      job.split(/\s+/)[3] == 'succeeded'
    end[/\d+/].to_i
  end

  private

  attr_reader :pipeline_name, :fly_target
end


pipeline_name = 'hello-world'
pipeline_path = 'pipeline.yml'
fly_target = 'pipeline-bling'

concourse = ConcourseWrapper.new(pipeline_name, fly_target)
lpass = LpassWrapper.new
secrets_parser = PipelineSecretParser.new

puts PipelineScanner.new(
    pipeline_name,
    pipeline_path,
    concourse,
    lpass,
    secrets_parser
).scan_for_leaks.to_json
