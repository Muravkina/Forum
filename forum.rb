require_relative 'db/connection'

module Forum
  class Server < Sinatra::Base

    configure do
      register Sinatra::Reloader
      set :sessions, true
    end

    def current_user
      session[:user_id]
    end

    def logged_in?
      !current_user.nil?
    end

    def is_current_user?
      current_user == params[:id]
    end

    def denied
      status 401
      "PERMISSION DENIED"
    end

    def get_geolocation
      url = "http://ipinfo.io/#{request.ip}/json"
      response = RestClient.get(url)
      @data = JSON.parse(response)
    end


    get '/' do
      redirect '/index'
    end

    get '/index' do
      erb :index
    end
########### SIGN UP##################
    post "/users" do
      name = params[:name]
      email = params[:email]
      password = params[:password]
      repeat_password = params[:repeat_password]

      is_user = $db.exec_params("SELECT * FROM users WHERE email = $1",[email])
        if is_user.ntuples == 0 && logged_in? == false
          if password == repeat_password
            user = $db.exec_params("INSERT INTO users (name, email, password) VALUES ($1, $2, $3) RETURNING id", [name, email, password]);
            user_id = user.first["id"]
            session[:user_id] = user_id
            redirect "/users/#{current_user}"
          else
            @authentication_message = "The password don't match"
          end
        elsif logged_in?
          @authentication_message = "You must log out before regestering a new member"
          erb :index
        elsif is_user != 0
          @authentication_message = "This email has been alredy registered"
          erb :index
      end
    end
########LOG IN#################
    post '/users/login' do
      email = params[:email]
      password = params[:password]
      @user = $db.exec_params("SELECT * FROM users WHERE email = $1 AND password = $2", [email, password])
      if @user.first == nil
        @message = "Invalid email or password"
        erb :index
      else
        user_id = @user.first["id"]
        session[:user_id] = user_id
        redirect '/topics'
      end
    end
##########PROFILE PAGE#############
    get '/users/:id' do
      if logged_in? && is_current_user?
        user = $db.exec_params("SELECT users.*,count(comments.id) AS user_num_comments, count(topics.id) AS num_topics FROM users LEFT JOIN comments ON comments.user_id = users.id LEFT JOIN topics ON topics.user_id = users.id WHERE users.id = $1 GROUP BY users.id;",[current_user]).first;
        @user_name = user["name"]
        @user_email = user["email"]
        @user_num_comments = user["user_num_comments"]
        @user_num_topics = user["num_topics"]
        @topics = $db.exec_params("SELECT topics.*,count(comments.id) AS topic_num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id WHERE topics.user_id = $1 GROUP BY topics.id", [current_user]);
        erb :user
      else
        denied
      end
    end
############EDIT PROFILE PAGE##############
    get '/users/:id/edit' do
      @id = params[:id]
      if logged_in? && is_current_user?
        user = $db.exec_params("SELECT * FROM users WHERE id = $1", [@id]).first
        @name = user["name"]
        @email = user["email"]
        erb :user_edit
      else
        denied
      end
    end
##########EDIT PROFILE#########
    patch '/users' do
      name = params[:name]
      email = params[:email]
      password = params[:password]
      $db.exec_params("UPDATE users SET name = $1, email = $2, password = $3 WHERE id = $4", [name, email, password, current_user])
      redirect "/users/#{current_user}"
    end
########DELETE PROFILE##########
    delete '/users' do
        $db.exec_params("DELETE FROM users WHERE id = $1", [current_user])
        redirect '/index'
    end
####### NEW TOPIC PAGE##############
    get '/topics/:id/new' do
      if logged_in?
        erb :topic_new
      else
        denied
      end
    end
######### CREATES NEW TOPIC###########
    post '/topics' do
      title = params[:title]
      message = params[:message]
      if get_geolocation != nil
        @location = @data["city"]
      end
      results = $db.exec_params("INSERT INTO topics (user_id, title, message, tag, created_at) VALUES ($1, $2, $3, $4, CURRENT_DATE) RETURNING id", [current_user, title, message, @location])
      binding.pry
      topic_id = results.first["id"]
      redirect "/topics/#{topic_id}"
    end
#####ONE TOPIC PAGE################
########available to all##############
    get '/topics/:id' do
      @topic_id = params[:id]
      @topic = $db.exec_params('SELECT * FROM topics WHERE id = $1', [@topic_id]).first
      @num_comments = $db.exec_params("SELECT count(*) FROM comments WHERE topic_id = $1", [@topic_id]).first["count"]
      user_id = @topic["user_id"]
      @topic_author = $db.exec_params("SELECT * FROM users WHERE id = $1", [user_id]).first["name"]
      @comments = $db.exec_params("SELECT comments.*, users.name AS comment_author FROM comments JOIN users ON users.id = comments.user_id WHERE comments.topic_id = $1", [@topic_id])
      if user_id == current_user
        @edit_topic = "Edit"
      end
      erb :topic
    end
#######EDIT TOPIC PAGE#########
    get '/topics/:topic_id/edit' do
      if  logged_in? && is_current_user?
        @topic_id = params[:topic_id]
        topic = $db.exec_params("SELECT * FROM topics WHERE id = $1", [@topic_id]).first
        erb :topic_edit
      else
        denied
      end
      end
########EDIT TOPIC#########
    patch '/topics/:topic_id' do
      $db.exec_params("UPDATE topics SET title = $1, message = $2 WHERE id = $3", [params[:title], params[:message], params[:topic_id]])
      redirect "/topics/#{params[:topic_id]}"
    end
  ######DELETE TOPIC######
    delete '/topics/:topic_id' do
      $db.exec_params("DELETE FROM topics WHERE id = $1", [params[:topic_id]])
      redirect ('/topics')
    end
##########ADD COMMENT PAGE#########
    get '/topics/:topic_id/comments/new' do
      if logged_in?
        @topic_id = params[:topic_id]
        topic = $db.exec_params("SELECT * FROM topics WHERE id = $1", [@topic_id]).first
        @title = topic["title"]
        @message = topic["message"]
        @topic_author = $db.exec_params("SELECT users.* FROM users JOIN topics ON topics.user_id = users.id WHERE topics.id = $1",[@topic_id]).first["name"]
        @user_name = $db.exec_params("SELECT * FROM users WHERE id = $1", [current_user]).first["name"]
        erb :new_comment
      else
        denied
      end
    end
###########ADD COMMENT###############
    post '/topics/:topic_id/comments' do
      subject = params[:subject]
      text = params[:message]
      topic_id = params[:topic_id]
      $db.exec_params("INSERT INTO comments (subject, message, user_id, topic_id, created_at) VALUES ($1,$2, $3, $4, CURRENT_DATE)", [subject, text, current_user, topic_id])
      redirect "/topics/#{topic_id}"
    end
##########EDIT COMMENT PAGE##################
    get '/topics/:topic_id/comments/:comment_id/edit' do
      if logged_in?
        @comment_id = params[:comment_id]
        @topic_id = params[:topic_id]
        topic = $db.exec_params("SELECT * FROM topics WHERE id = $1", [@topic_id]).first
        @title = topic["title"]
        @message = topic["message"]
        @topic_author = $db.exec_params("SELECT users.* FROM users JOIN topics ON topics.user_id = users.id WHERE topics.id = $1",[@topic_id]).first["name"]
        @user_name = $db.exec_params("SELECT * FROM users WHERE id = $1", [current_user]).first["name"]
        erb :comment_edit
      else
        denied
      end
    end
###########EDIT COMMENT#################
    patch '/topics/:topic_id/comments/:comment_id' do
      topic_id = params[:topic_id]
      comment_id = params[:comment_id]
      subject = params[:subject]
      text = params[:message]
      $db.exec_params("UPDATE comments SET subject = $1, message = $2 WHERE id = $3", [subject, text, comment_id])
      binding.pry
      redirect "/topics/#{topic_id}"
    end
##########DELETE COMMENT##############
    delete '/topics/:topic_id/comments/:comment_id' do
      $db.exec_params("DELETE FROM comments WHERE id = $1", [params[:comment_id]])
      redirect "/topics/#{params[:topic_id]}"
    end
########PAGE WITH ALL THE TOPICS FROM ALL USERS########
#########available to anyone################
    get '/topics' do
      @topics = $db.exec("SELECT topics.*,count(comments.id) AS num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id GROUP BY topics.id");
      erb :topics
    end
###########TOPICS BY THE TAG#################
    get "/topics/:topic_tag" do
      @topics = $db.exec_params("SELECT topics.*,count(comments.id) AS num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id GROUP BY topics.id WHERE topics.tag = $1",[params[topic_tag]]);
      erb :topics_tag
    end
###########LOG OUT########################
    delete '/users/login' do
      session[:user_id] = nil
      redirect '/index'
    end

  end
end
