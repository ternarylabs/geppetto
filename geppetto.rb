#!/usr/bin/env ruby
unless $LOAD_PATH.include?(File.expand_path(File.join(File.dirname(__FILE__), "vendor/koala/lib")))
#  $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), "vendor/koala/lib"))
end

require 'rubygems'
require 'thor'
require 'koala'
require 'ostruct'
require 'yaml'
require 'progressbar'
require 'rmagick'
require 'tempfile'

include Koala

if File.exist?("settings.yaml")
  ::Settings = OpenStruct.new(YAML.load_file("settings.yaml"))
else
  say "You need to create a settings.yaml file"
  exit
end

class Geppetto < Thor 
  include Thor::Actions
  
  def initialize(*args)
    @test_users = Facebook::TestUsers.new(:app_id => Settings.development['app_id'], :secret => Settings.development['secret'])
    super
  end

  desc "create [NB]", "Create one or many test users"
  method_option :connected, :type => :boolean, :default => true, :alias => :string, :desc => "Whether the user has 'installed' the FB application"
  method_option :permissions, :type => :array, :default => Settings.development['default_permissions'], :aliases => "-p", :desc => "Access permissions"
  method_option :networked, :type => :boolean, :default => false, :alias => :string, :desc => "Automatically befriend every user with each other"
  def create(nb=1)
    create_users(nb, options.connected?, options.networked?, options[:permissions])
  end
  
  desc "list", "List all test users"
  def list
    users_hash = @test_users.list
    say "Listing #{users_hash.size} test users"
    users_hash.each{|user_hash|
      dump(user_hash)
    }
  end

  desc "delete ID", "Delete a test user"
  def delete(id)
    if yes? "Are you sure?"
      @test_users.delete(id)
      say "Deleted 1 user", :red
    end
  end

  desc "delete_all", "Delete all test users"
  def delete_all
    if yes? "Are you sure you want to delete ALL existing test users?"
      size = @test_users.list.size
      @test_users.list.each{|user_hash|
        @test_users.delete(user_hash)
      }
      say "Deleted #{size} users", :red
    end
  end
  
  desc "about ID", "Display information about the given user"
  def about(id)
    @graph = Facebook::GraphAPI.new(get_token_for_user_id(id))
    account = @graph.get_object("me")    
    dump(account)
  end

  desc "befriend ID1 ID2", "Friend two users"
  def befriend(id1, id2)
    @test_users.befriend(get_user_hash(id1), get_user_hash(id2))
  end
  
  desc "wall_post ID TEXT", "Post to the user's wall"
  def wall_post(id, text)
    @graph = Facebook::GraphAPI.new(get_token_for_user_id(id))
    @graph.put_wall_post(text)
  end

  desc "generate_posts", "Every user will post to their feeds/walls"
  def generate_posts
    users_hash = @test_users.list
    progress = ProgressBar.new("Posting #{users_hash.size}", users_hash.size)
    users_hash.each{|user_hash|
      progress.inc
      # Post on the user's wall
      @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))
      @graph.put_wall_post("Post created at #{Time.now}")

      # Post on friend's wall
      friends = @graph.get_connections(user_hash['id'], 'friends')
      friends.each{|friend_hash|
        @graph.put_wall_post("Post created at #{Time.now}", {}, friend_hash['id'])
      }
    }
    progress.finish
  end

  desc "generate_likes", "Every user will like all their friend's posts"
  def generate_likes
    users_hash = @test_users.list
    progress = ProgressBar.new("Liking #{users_hash.size}", users_hash.size)
    users_hash.each{|user_hash|
      progress.inc
      # Get this user's feed
      @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))
      feed = @graph.get_connections(user_hash['id'], 'feed')
      feed.each {|item|
        @graph.put_like(item['id'])
      }
    }
    progress.finish
  end

  desc "generate_comments", "Every user will add a comment to each post in their feed"
  def generate_comments
    users_hash = @test_users.list
    progress = ProgressBar.new("Commenting #{users_hash.size}", users_hash.size)
    users_hash.each{|user_hash|
      progress.inc
      # Get this user's feed
      @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))
      feed = @graph.get_connections(user_hash['id'], 'feed')
      feed.each {|item|
        @graph.put_comment(item['id'], "Comment created at #{Time.now}")
      }
    }
    progress.finish
  end

  desc "generate_images", "Every user will post a picture to their feed"
  def generate_images
    users_hash = @test_users.list
    progress = ProgressBar.new("Imaging #{users_hash.size}", users_hash.size)
    users_hash.each{|user_hash|
      progress.inc
      # Get this user's feed
      @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))
      file = Tempfile.new('geppetto')
      begin
        create_image(file.path)
        @graph.put_picture(file.path, 'image/jpeg', {:message => "Image created at #{Time.now}"})
      ensure
        file.close
        file.unlink
      end
    }
    progress.finish
  end
  
  desc "build", "Built test user network and generate posts, likes, images"
  def build
    delete_all
    create_users(10, true, true, Settings.development['default_permissions'])
    generate_posts
    generate_images
    generate_comments
    generate_likes
  end
  
  private
  def dump(hash)
    say "-" * 80
    max_key_width = hash.keys.collect{|key| key.size}.max
    format_string = "%#{max_key_width}s: %s"
    hash.each{|key,value| say format(format_string, key, value)}
    say "-" * 80
  end
  
  def get_user_hash(user_id)
    if user_id
      @test_users.list.each {|user_hash| return user_hash if user_hash['id'] == user_id}
    end
    raise Facebook::APIError.new({"type" => 'Error', 'message' => "This user id is unknown"})
  end
  
  def get_token_for_user_id(user_id)
    return get_user_hash(user_id)['access_token']
  end

  # Crate an image containing text
  def create_image(file)
    image = Magick::Image.new(320, 240, Magick::HatchFill.new("##{'%02X' % rand(255)}#{'%02X' % rand(255)}#{'%02X' % rand(255)}"))
    image.format = "jpg"
    image.write(file)
  end
  
  def create_users(nb, connected, networked, permissions)
    if networked
      say "Creating #{nb} networked test users"
      users_hash = @test_users.create_network(nb.to_i, connected, permissions.join(","))
      users_hash.each{|user_hash|
        dump(user_hash)
      }      
    else
      say "Creating #{nb} test users"      
      while(nb.to_i > 0)      
        user_hash = @test_users.create(connected, permissions.join(","))
        dump(user_hash)
        nb = nb.to_i-1
      end
    end    
  end
end

begin
  Koala.always_use_ssl=true
  Geppetto.start
rescue Facebook::APIError => e
  say e
end