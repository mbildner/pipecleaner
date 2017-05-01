require 'yaml'

base = YAML.load_file('pipeline.yml')['jobs'][0]

def make_job(base, index)
  base = Marshal.load(Marshal.dump(base))

  base['name'] = "#{base['name']}-#{index}"

  (secret_name, secret_value) = base['plan'][0]['config']['params'].entries.first

  k = "#{secret_name}_#{index}"

  params_hash = {}
  params_hash[k] = secret_value.gsub("description", "description_#{index}")

  base['plan'][0]['config']['params'] = params_hash

  base['plan'][0]['config']['run']['args'][1] = "echo \"${VERY_SECRET_KEY_#{index}\""

  base
end

pipeline = YAML.load_file('pipeline.yml')
pipeline['jobs'] = []

lpass_note = {}
799.times do |i|
  pipeline['jobs'] << make_job(base, i)
  lpass_note["description_#{i}"] = "lastpass secret value number #{i}"
end

File.write('generated_pipeline.yml', pipeline.to_yaml)
