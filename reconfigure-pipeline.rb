require 'yaml'
require 'tempfile'

def temp_pipeline_file
  f = Tempfile.new('generated_concourse.yml')

  yaml = File.read('pipeline.yml').gsub(/\({2}(.+)\){2}/) do |lpass_key|
    cleaned_key = lpass_key[2..-3]
    note_name, key_name = cleaned_key.split('/Notes/')
    YAML.load(`lpass show --notes \"#{note_name}\"`)[key_name]
  end

  f.write(yaml)
  f.rewind

  f
end

cmd = "fly -t pipeline-bling set-pipeline -p hello-world -c #{temp_pipeline_file.path}"
system cmd
