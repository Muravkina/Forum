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
      url = "http://ipinfo.io/json"
      response = RestClient.get(url)
      @data = JSON.parse(response)
    end

    def not_empty? (title)
      !title.nil? && title != ""
    end

    before do
      @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
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
      if logged_in? == false
        if not_empty?(password) && not_empty?(name) && not_empty?(email)
          if password == repeat_password
            user = $db.exec_params("INSERT INTO users (name, email, password) SELECT $1, $2::varchar, $3 WHERE NOT EXISTS (SELECT email FROM users WHERE email = $2) RETURNING id", [name, email, password]);
            if user.entries != []
              user_id = user.first["id"]
              session[:user_id] = user_id
              redirect "/users/#{current_user}"
            else
              @authentication_message = "This email has been already registered"
              erb :index
            end
          else
            @authentication_message = "The passwords don't match"
            erb :index
          end
        else
          @authentication_message = "Please, fill out all the forms"
          erb :index
        end
      else
        @authentication_message = "You must log out before regestering a new member"
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
        user = $db.exec_params("SELECT users.*,count(comments.id) AS user_num_comments, count(topics.id) AS num_topics, topics.num_votes FROM users LEFT JOIN comments ON comments.user_id = users.id LEFT JOIN topics ON topics.user_id = users.id WHERE users.id = $1 GROUP BY users.id, topics.id;",[current_user]).first;
        @user_name = user["name"]
        @user_email = user["email"]
        @user_num_comments = user["user_num_comments"]
        @user_num_topics = user["num_topics"]
        @topics = $db.exec_params("SELECT topics.*,count(comments.id) AS topic_num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id WHERE topics.user_id = $1 GROUP BY topics.id ORDER BY topics.num_votes DESC", [current_user]);
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
    patch '/users/:user_id/delete' do
        email = ""
        password = ""
        $db.exec_params("UPDATE users SET email = $1, password = $2 WHERE id = $3",[email, password, params[:user_id]])
        session[:user_id] = nil
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
      @title = params[:title]
      @message = @markdown.render(params[:message])

      if get_geolocation != nil
        @location = @data["city"]
      end
      if not_empty? (@title)
        if not_empty? (@message)
          binding.pry
          results = $db.exec_params("INSERT INTO topics (user_id, title, message, tag, created_at) VALUES ($1, $2, $3, $4, CURRENT_DATE) RETURNING id", [current_user, @title, @message, @location])
          topic_id = results.first["id"]
          redirect "/topics/#{topic_id}"
        else
          @empty_message = "Don't forget to add the text"
          erb :topic_new
        end
      else
        @empty_title = "Don't forget to add the title"
        erb :topic_new
      end
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
      if  logged_in?
        @topic_id = params[:topic_id]
        topic = $db.exec_params("SELECT * FROM topics WHERE id = $1", [@topic_id]).first
        erb :topic_edit
      else
        denied
      end
    end
########EDIT TOPIC#########
    patch '/topics/:topic_id' do
      message = @markdown.render(params[:message])
      $db.exec_params("UPDATE topics SET title = $1, message = $2 WHERE id = $3", [params[:title], message, params[:topic_id]])
      redirect "/topics/#{params[:topic_id]}"
    end
  ######DELETE TOPIC######
    delete '/topics/:topic_id' do
      $db.exec_params("DELETE FROM comments WHERE topic_id = $1",[params[:topic_id]])
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
      @subject = params[:subject]
      text = @markdown.render(params[:message])
      topic_id = params[:topic_id]
      if not_empty?(text)
        $db.exec_params("INSERT INTO comments (subject, message, user_id, topic_id, created_at) VALUES ($1,$2, $3, $4, CURRENT_DATE)", [@subject, text, current_user, topic_id])
        redirect "/topics/#{topic_id}"
      else
        @empty_message = "Don't forget to add the comment"
        erb :new_comment
      end
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
      text = @markdown.render(params[:message])
      if not_empty?(text)
        $db.exec_params("UPDATE comments SET subject = $1, message = $2 WHERE id = $3", [subject, text, comment_id])
        redirect "/topics/#{topic_id}"
      else
        @empty_message = "Don't forget to add the comment"
        erb :comment_edit
      end
    end
##########DELETE COMMENT##############
    delete '/topics/:topic_id/comments/:comment_id' do
      $db.exec_params("DELETE FROM comments WHERE id = $1", [params[:comment_id]])
      redirect "/topics/#{params[:topic_id]}"
    end
########PAGE WITH ALL THE TOPICS FROM ALL USERS########
#########available to anyone################
    get '/topics' do
      @topics = $db.exec("SELECT topics.*,count(comments.id) AS num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id GROUP BY topics.id ORDER BY topics.num_votes DESC");
      erb :topics
    end
###########TOPICS BY THE TAG#################
    get "/topics/all/:topic_tag" do
      @topics = $db.exec_params("SELECT topics.*,count(comments.id) AS num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id WHERE topics.tag = $1 GROUP BY topics.id ORDER BY topics.num_votes DESC",[params[:topic_tag]]);
      erb :topics_tag
    end
###########LOG OUT########################
    delete '/users/login' do
      session[:user_id] = nil
      redirect '/index'
    end

    patch '/topics/:topic_id/tag' do
      $db.exec_params("UPDATE topics SET num_votes = (num_votes + 1) WHERE id = $1", [params[:topic_id]])
      redirect  "/topics/#{params[:topic_id]}"
    end

  end
end
