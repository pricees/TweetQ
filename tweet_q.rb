require 'net/http'
require 'rubygems'
require 'json'

class TweetQ
  class Tweet
    MAX_STATUS_LENGTH = 140
    class StringTooBigError < StandardError;end

    def self.username=(username); @@username=username end
    def self.password=(password); @@password=password end

    attr_accessor :status, :id, :created_at

    def initialize(hash={})
      hash.each { |k,v| send(k.to_s+"=", v) if respond_to?(k) }
    end
 
    def to_s; status; end 
    def info;"#{id}: #{status} #{created_at}"; end

    def destroy; post id, :destroy; end

    # Sends a new status
    def queue
      raise StringTooBigError if status.length > MAX_STATUS_LENGTH
      api_url = 'http://twitter.com/statuses/update.json'
      url = URI.parse(api_url)
      req = Net::HTTP::Post.new(url.path)
      req.basic_auth(@@username, @@password)
      req.set_form_data({ 'status'=> status }, ';')
      res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }.body
      @id = JSON.parse(res)["id"]
      @created_at = JSON.parse(res)["created_at"]
      self
    end

    # Gets Statuses
    def self.dequeue(count = 1)
      api_url = 'http://twitter.com/statuses/user_timeline/' + @@username + ".json?count=" + count.to_s
      url = URI.parse(api_url)
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }.body
      JSON.parse(res).collect { |json| Tweet.new({ :status => json["text"], :id => json['id'].to_i, :created_at => json["created_at"] }) }
    end

    protected 

    def post(id, action)
      twitter_url = "http://twitter.com/statuses/#{action}/#{id}.json"
      url = URI.parse(twitter_url)
      req = Net::HTTP::Post.new(url.path)
      req.basic_auth(@@username, @@password)
      req.set_form_data({ 'id' => id }, ';')
      Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    end
  end

  # Queue Features

  def initialize(username,password)
    Tweet.username = username
    Tweet.password = password
  end

  def queue(status)
    Tweet.new({:status => status }).queue
  end

  def dequeue(num=1)
    dequeue = Tweet.dequeue(num)
    master_queue << dequeue
    master_queue.flatten!
    dequeue
  end

  #Holds everything in memory
  def master_queue; @master_queue ||= []; end
end
