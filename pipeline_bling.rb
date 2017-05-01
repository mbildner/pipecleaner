require 'yaml'
require 'json'

class PipelineScanner
  def initialize(pipeline_name)
    @pipeline_name = pipeline_name
  end

  def scan_for_leaks
    notes = lpass_notes
    jobs.map do |job_name|
      run_id = last_successful_run(job_name)
      log = logs_for_build(job_name, run_id)
      notes.map do |note|
        note['note'].map do |k, v|
          if log.include?(v)
            {
              "pipeline" => pipeline_name,
              "job" => job_name,
              "build" => run_id,
              "key" => k,
              "note" => note['name']
            }
          end
        end
      end
    end.flatten.compact
  end
  private

  attr_reader :pipeline_name

  def pipelines
    `fly -t pipeline-bling pipelines --all`.split("\n").map{|l| l.split(/\s/)[0] }
  end

  def lpass_notes
    File.read('pipeline.yml')
      .scan(/\({2}(.+)\){2}/)
      .map(&:first)
      .map{|full_note_path| full_note_path.split('/Notes/')[0]}
      .map{|note_name| { "name" => note_name, "note" => YAML.load(`lpass show --notes "#{note_name}"`) }}
  end

  def jobs
    YAML.load(`fly -t pipeline-bling get-pipeline -p #{pipeline_name}`)['jobs'].map{|job| job['name'] }
  end

  def last_successful_run(job_name)
    `fly -t pipeline-bling builds -j #{pipeline_name}/#{job_name}`.split("\n").find{|job| job.split(/\s+/)[3] == 'succeeded' }[/\d+/].to_i
  end

  def logs_for_build(job_name, build)
    `fly -t pipeline-bling watch -j #{pipeline_name}/#{job_name} -b #{build}`
  end
end

puts PipelineScanner.new('hello-world').scan_for_leaks.to_json
