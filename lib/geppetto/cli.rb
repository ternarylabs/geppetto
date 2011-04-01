require 'thor'
require 'koala'
require 'ostruct'
require 'yaml'
require 'progressbar'
require 'tempfile'

module Geppetto
  class CLI < Thor 
    include Koala

    method_option :env, :type => :string, :default => 'dev', :desc => "App environment"  
    def initialize(*args)
      super
      unless Settings[options.env]
        puts "Environement #{options.env} is not defined in the settings.yaml file"
        exit
      end
      @test_users = Facebook::TestUsers.new(:app_id => Settings[options.env]['app_id'], :secret => Settings[options.env]['secret'])
    end

    desc "version", "Show program version"
    def version
      say "Version: #{::Geppetto::VERSION}", :white
    end
  
    desc "create [NB]", "Create one or many test users"
    method_option :connected, :type => :boolean, :default => true, :alias => :string, :desc => "Whether the user has 'installed' the FB application"
    method_option :networked, :type => :boolean, :default => false, :alias => :string, :desc => "Automatically befriend every user with each other"
    def create(nb=1)
      create_users(nb, options.connected?, options.networked?, Settings[options.env]['default_permissions'])
    end
  
    desc "list", "List all test users"
    def list
      users_hash = @test_users.list
      say "Listing #{users_hash.size} test users", :white
      users_hash.each{|user_hash|
        dump(user_hash)
      }
    end

    desc "delete ID", "Delete a test user"
    def delete(id)
      if yes? "Are you sure you want to delete user #{id}?", :red
        @test_users.delete(id)
        say "Deleted 1 user", :white
      end
    end

    desc "delete_all", "Delete all test users"
    def delete_all
      if yes? "Are you sure you want to delete ALL existing test users?", :red
        size = get_test_users.size
        say "Deleting #{size} users", :white
        progress = ProgressBar.new("Deleting", size)
        get_test_users.each{|user_hash|
          @test_users.delete(user_hash)
          progress.inc
        }
        progress.finish
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

    desc "generate_status", "Every user will post a new status update"
    def generate_status
      users_hash = get_test_users
      say "Posting status for #{users_hash.size} users", :white
      progress = ProgressBar.new("Posting", users_hash.size)
      users_hash.each{|user_hash|
        # Post on the user's wall
        @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))
        @graph.put_wall_post("Status update created at #{Time.now}")
        progress.inc
      }
      progress.finish
    end

    desc "generate_posts", "Every user will post on their friend's wall"
    def generate_posts
      users_hash = get_test_users
      say "Posting for #{users_hash.size} users", :white
      users_hash.each{|user_hash|
        @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))

        # Post on friend's wall
        friends = @graph.get_connections(user_hash['id'], 'friends')
        progress = ProgressBar.new("Posting", friends.size)
        friends.each{|friend_hash|
          @graph.put_wall_post("Post created at #{Time.now}", {}, friend_hash['id'])
          progress.inc
        }
        progress.finish
      }
    end

    desc "generate_likes", "Every user will like all their friend's posts"
    def generate_likes
      users_hash = get_test_users
      say "Posting likes for #{users_hash.size} users", :white
      users_hash.each{|user_hash|
        # Get this user's feed
        token = get_token_for_user_id(user_hash['id'])
        @graph = Facebook::GraphAPI.new(token)
        feed = @graph.get_connections('me', 'home')
        progress = ProgressBar.new("Liking", feed.size)
        feed.each {|item|
          @graph.put_like(item['id'])
          progress.inc
        }
        progress.finish
      }
    end

    desc "generate_comments", "Every user will add a comment to each post in their feed"
    def generate_comments
      users_hash = get_test_users
      say "Posting comments for #{users_hash.size} users", :white
      users_hash.each{|user_hash|
        # Get this user's feed
        @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))
        feed = @graph.get_connections('me', 'home')
        progress = ProgressBar.new("Comments", feed.size)
        feed.each {|item|
          @graph.put_comment(item['id'], "Comment created at #{Time.now}")
          progress.inc
        }
        progress.finish
      }
    end

    desc "generate_images", "Every user will post a picture to their feed"
    def generate_images
      users_hash = get_test_users
      say "Posting images for #{users_hash.size} users", :white
      progress = ProgressBar.new("Images", users_hash.size)
      users_hash.each{|user_hash|
        # Get this user's feed
        @graph = Facebook::GraphAPI.new(get_token_for_user_id(user_hash['id']))
        file_path = File.join(File.dirname(__FILE__), '320_240.png')
        @graph.put_picture(file_path, 'image/png', {:message => "Image created at #{Time.now}"})
        progress.inc
      }
      progress.finish
    end

    desc "build", "Built test user network and generate posts, likes, images"
    def build
      say "Build test setup", :white
      delete_all
      create_users(10, true, true, Settings[options.env]['default_permissions'])
      generate_status
      generate_posts
      generate_images
      generate_comments
      generate_likes
    end

    desc "frenzy", "Genera posts, likes, images, etc. for all users in a random fashion. CTRL-C to cancel."
    def frenzy
      say "Frenzy! (CTRL-C to stop)", :white
      actions = %w(generate_status generate_posts generate_images generate_comments generate_likes)
      while (true) 
        send actions[rand(actions.size)]
        say "Sleeping"
        sleep 2.0
      end
    end
  
    private
    def dump(hash)
      say "-" * 80
      max_key_width = hash.keys.collect{|key| key.size}.max
      format_string = "%#{max_key_width}s: %s"
      hash.each{|key,value| say format(format_string, key, value)}
      if hash.has_key?('access_token') 
        say format(format_string, 'app_login',  "#{Settings[options.env]['app_url']}?access_token=#{hash['access_token']}&expires_in=0")
      end
      say "-" * 80
    end

    # Returned a sanitized version of the test users list. For some reason, some test users
    # are now returned without oauth access token.
    def get_test_users
      @test_users.list.delete_if {|user_hash| !user_hash.include?('access_token') }
    end
  
    def get_user_hash(user_id)
      if user_id
        get_test_users.each {|user_hash| return user_hash if user_hash['id'] == user_id}
      end
      raise Facebook::APIError.new({"type" => 'Error', 'message' => "This user id is unknown"})
    end
  
    def get_token_for_user_id(user_id)
      return get_user_hash(user_id)['access_token']
    end
  
    def create_users(nb, connected, networked, permissions)
      if networked
        say "Creating #{nb} networked test users", :white
        users_hash = create_network(nb.to_i, connected, permissions.join(","))
        users_hash.each{|user_hash|
          dump(user_hash)
        }      
      else
        say "Creating #{nb} test users", :white  
        while(nb.to_i > 0)      
          user_hash = @test_users.create(connected, permissions.join(","))
          dump(user_hash)
          nb = nb.to_i-1
        end
      end    
    end  
  
    def create_network(network_size, installed = true, permissions = '')
      network_size = 100 if network_size > 100
      progress = ProgressBar.new("Creating", network_size)
      users = (0...network_size).collect { 
        progress.inc
        @test_users.create(installed, permissions) 
      }
      progress.finish

      friends = users.clone
      users.each do |user|
        # Remove this user from list of friends
        friends.delete_at(0)
        # befriend all the others
        friends.each do |friend|
          say "Befriending #{user['id']} #{friend['id']}"
          begin
            @test_users.befriend(user, friend)
          rescue Facebook::APIError => e
            say "Problem befriending: #{e}", :red
          end
        end
      end
      return users
    end  
  end
end