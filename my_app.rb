require 'rubygems'
require 'sinatra'
require 'json'
require 'pp' if ENV['RACK_ENV'] == 'development'

require './config/init.rb'

STATUS_OK = 0
STATUS_ERROR = 1
STATUS_UNREGISTERED = 2
STATUS_ALREADY_WATCHED = 3

MINIMUM_VERSION = 73

helpers do
	def slack_webhook_uri
		URI.join(ENV['SLACK_URL'], "services/hooks/incoming-webhook?token=#{ENV['SLACK_TOKEN']}")
	end
  
  def agent_version
    agent = request.env['HTTP_USER_AGENT']
    if agent
      matches = /^\w+\/(\d+)\s/.match(agent)
      if matches
        version = matches[1]
      else
        version = 9999
      end
    else
      version = 9999
    end
  end
  
end

get '/' do
  halt 404
end

get '/status' do
  erb :index
end

get '/status/table' do
  
  # @people = Person.where{version >= MINIMUM_VERSION}.select_order_map([:name, :status])
  # @count = Person.where(:status => 'In').where{version >= MINIMUM_VERSION}.count

  @people = Person.select_order_map([:name, :status])
  @count = Person.where(:status => 'In').count

  erb :table
  
end

get '/status/list' do
  
  DB.transaction do
    DB.fetch("update people set status = 'Stale' where date < NOW() - INTERVAL '1 DAY' and status != 'Stale';")
  end
  
#  people = Person.order(:name).where{version >= MINIMUM_VERSION}
  people = Person.order(:name)
  
  if params[:name]
    lowName = params[:name].downcase
    requestor = Person[:name => lowName]
    halt 400 unless requestor
  end

  content_type :json
  
  output = []
  
  people.each do |p|
    
    watched_by = false
    watches = false
    
    if requestor
      watched_by = p.watched_by_name(requestor.name)
      watches = p.watches_name(requestor.name)
    end
    
    output << { "status" => p.status, "name" => p.name, "watched_by_requestor" => watched_by, "watches_requestor" => watches }
  end
  
  output.to_json
  
end

post '/status/update' do
  content_type :json
  
  halt 400 if !params[:name]
  halt 400 if !params[:status]
  output = ""
  
  DB.transaction do
  
    lowName = params[:name].downcase
    lowName = 'steven' if lowName == 'stevenf'
  
    person = Person.for_update.first(:name => lowName)
    
    if !person
      person = Person.new()
      output = {"result" => STATUS_UNREGISTERED, "msg" => "Name not found"}.to_json
    else
      
      status_changed = params[:status] != person.status
      output = {"result" => STATUS_OK, "status_changed" => status_changed}.to_json
      
      if status_changed
        # Send notifications
#        count = Person.where(:status => 'In').where{version >= MINIMUM_VERSION}.count
        count = Person.where(:status => 'In').count
        
        recipient_ids = []
        person.watchers.each do |w|
          if w.push_id != ""
            recipient_ids << w.push_id
            puts "Queuing notification for #{w.name}"
          end
        end
        
        if recipient_ids.count > 0
          ZeroPush.notify({
            device_tokens: recipient_ids,
            alert: "#{person.name.capitalize!} is #{params[:status]}",
            sound: "status.caf",
            badge: "",
            info: ""
          })
        end
      end
    end
        
    person.status = params[:status]
    person.name = lowName
    person.push_id = params[:push_id]
    person.beacon_minor = params[:beacon_minor]
    person.version = agent_version
    person.date = DateTime.now
    person.save or {"result" => STATUS_ERROR, "reason" => "The record could not be saved"}.to_json
    
    
    puts "STATUS UPDATE: #{person.name.capitalize!} is #{params[:status]}"
  end


  output
end

post '/message/in' do
  
  content_type :json
  
  halt 400 if !params[:name]
  halt 400 if !params[:message]
  
  lowName = params[:name].downcase
  lowName = 'steven' if lowName == 'stevenf'
  
  sender = Person.first(:name => lowName)
  in_people = Person.where(:status => 'In')

  recipient_ids = []

  in_people.each do |p|
    if p.push_id != ""
      recipient_ids << p.push_id
      puts "Queuing message notification for #{p.name}"
    end
  end
  
  if recipient_ids.count > 0
    ZeroPush.notify({
      device_tokens: recipient_ids,
      alert: "#{sender.name.capitalize!}: #{params[:message]}",
      sound: "message.caf",
      badge: "",
      info: ""
    })
  end
  
  {"result" => STATUS_OK}.to_json
  
end

post '/watch/:target' do
  content_type :json
  
  halt 400 if !params[:target]
  halt 400 if !params[:name]
  
  target = Person[:name => params[:target].downcase]
  watcher = Person[:name => params[:name].downcase]
  
  if target.watched_by_name(watcher.name)
    { "status" => STATUS_ALREADY_WATCHED }.to_json
  else
    target.add_watcher(watcher)
    { "status" => STATUS_OK }.to_json
  end
  
end

post '/unwatch/:target' do
  content_type :json

  halt 400 if !params[:target]
  halt 400 if !params[:name]

  target = Person[:name => params[:target].downcase]
  watcher = Person[:name => params[:name].downcase]
  
  if target.watched_by_name(watcher.name)
    target.remove_watcher(watcher)
  end

  { "status" => STATUS_OK }.to_json

end

get '/image/:name' do
  
  halt 400 if !params[:name]
  
  image_name = "#{params[:name]}.png"
  image_path = File.expand_path(image_name, settings.public_folder)
  
  if File.exists?(image_path)
    send_file image_path
  else
    send_file File.expand_path("unknown.png", settings.public_folder)
  end
  
end