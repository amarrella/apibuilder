#!/usr/bin/env ruby

load 'ruby_client.rb'
CLIENT_DIR = "src/main/scala/clients"

service_uri = ARGV.shift

token = ARGV.shift
if service_uri.to_s.strip == "" || token.to_s.strip == ""
  raise "service uri and token required"
end

orgs = ['gilt']
#services = ['api-doc']

class Target

  attr_reader :platform, :test_command, :names

  def initialize(platform, test_command, names)
    @platform = platform
    @test_command = test_command
    @names = names
  end

end

targets = [Target.new('play_2_2', 'sbt compile', ['play_2_2_client', 'play_2_x_json', 'scala_models']),
           Target.new('play_2_3', 'sbt compile', ['play_2_3_client', 'play_2_x_json', 'scala_models'])]

def write_target(platform, org, service, target, code)
  filename = File.join(platform, CLIENT_DIR, [org.key, service.key, "#{target.value}.downloaded.scala"].join("."))
  File.open(filename, "w") do |out|
    out << "package clienttests_#{target.value} {\n\n"
    out << code.source
    out << "\n\n}"
  end
  filename
end

def get_code(client, org, service, target)
  client.code.get_by_org_key_and_service_key_and_version_and_target(org.key, service.key, "latest", target)
end

cmd = "rm -f #{CLIENT_DIR}/*.downloaded.scala"
puts cmd
system(cmd)

client = ApiDoc::Client.new(service_uri, :authorization => ApiDoc::HttpClient::Authorization.basic(token))

targets.each do |target|
  puts "Platform: #{target.platform}"
  puts "--------------------------------------------------"
  client.organizations.get.each do |org|
    next unless orgs.include?(org.key)
    client.services.get_by_org_key(org.key).each do |service|
      #next unless services.include?(service.key)
      puts "  %s/%s" % [org.key, service.key]
      target.names.each do |target_name|
        t = ApiDoc::Models::Target.send(target_name)
        if code = get_code(client, org, service, t)
          filename = write_target(target.platform, org, service, t, code)
          puts "    #{t.value}: #{filename}"
        end
      end
    end
  end

  puts ""
  puts "  cd ./#{target.platform} && #{target.test_command}"
  Dir.chdir(target.platform) do
    if system(target.test_command)
      puts "  - All clients compiled"
    else
      puts "  - Clients failed to compile"
      exit 1
    end
  end
end