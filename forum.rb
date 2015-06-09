require_relative 'db/connection'

module Forum
  class Server < Sinatra::Base

    configure :production do
      set :sessions, true
      require 'uri'
      uri = URI.parse ENV['DATABASE_URL']
      $db = PG.connect dbname: uri.paath[1..-1],
            host: uri.host,
            post: uri.port,
            user: uri.user,
            password: uri.password
    end

    configure :development do
      $db = PG.connect dbname: 'forum', host: "localhost"

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
        user = $db.exec_params("SELECT users.*,count(comments.id) AS user_num_comments, topics.num_votes FROM users LEFT JOIN comments ON comments.user_id = users.id LEFT JOIN topics ON topics.user_id = users.id WHERE users.id = $1 GROUP BY users.id, topics.id",[params[:id]]).first;
        @user_img = user["img_url"]
        @user_name = user["name"]
        @user_email = user["email"]
        @user_num_comments = user["user_num_comments"]
        @user_num_topics =  $db.exec_params("select count(*) from topics where user_id = $1",[current_user]).first["count"]
        @topics = $db.exec_params("SELECT topics.*,count(comments.id) AS topic_num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id WHERE topics.user_id = $1 GROUP BY topics.id ORDER BY topics.num_votes DESC",[params[:id]]);
        erb :user
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
      if not_empty?(params[:name])
        name = params[:name]
      else
         name = $db.exec_params("SELECT * FROM users WHERE id = $1",[current_user]).first["name"]
      end
      if not_empty?(params[:email])
        email = params[:email]
      else
        email = $db.exec_params("SELECT * FROM users WHERE id = $1",[current_user]).first["email"]
      end
      if not_empty?(params[:password])
        password = params[:password]
      else
        password = $db.exec_params("SELECT * FROM users WHERE id = $1",[current_user]).first["password"]
      end
      if not_empty?(params[:img_url])
        img_url = params[:img_url]
      else
        img_url = $db.exec_params("SELECT * FROM users WHERE id = $1",[current_user]).first["img_url"]
      end
        $db.exec_params("UPDATE users SET name = $1, email = $2, password = $3, img_url = $5 WHERE id = $4", [name, email, password, current_user, img_url])
        redirect "/users/#{current_user}"
    end
########DELETE PROFILE##########
    patch '/users/:user_id/delete' do
        email = ""
        password = ""
        name = ""
        $db.exec_params("UPDATE users SET email = $1, password = $2, name = $4 WHERE id = $3",[email, password, params[:user_id], name])
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
      if @data != nil && @data != ""
        @location = @data["city"]
        tags = "#{@location.gsub(" ", "")}, #{params[:tags]}".gsub(",", "").gsub("#", "")
      end
      if not_empty? (@title)
        if not_empty? (@message)
          results = $db.exec_params("INSERT INTO topics (user_id, title, message, tag, created_at) VALUES ($1, $2, $3, $4, CURRENT_DATE) RETURNING id", [current_user, @title, @message, tags])
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
      @user_id = @topic["user_id"]
      @user_img = $db.exec_params("SELECT * FROM users WHERE id = $1", [@user_id]).first["img_url"]
      @topic_author = $db.exec_params("SELECT * FROM users WHERE id = $1", [@user_id]).first["name"]
      @comments = $db.exec_params("SELECT comments.*, users.name AS comment_author, users.img_url AS author_img FROM comments JOIN users ON users.id = comments.user_id WHERE comments.topic_id = $1", [@topic_id])
      if @user_id == current_user
        @edit_topic = "Edit"
      end
      if !logged_in?
        @empty_message = "You have to be a member to leave a message"
      end


      erb :topic
    end
#######EDIT TOPIC PAGE#########
    get '/topics/:topic_id/edit' do
      if  logged_in?
        @topic_id = params[:topic_id]
        @topic = $db.exec_params("SELECT * FROM topics WHERE id = $1", [@topic_id]).first
        erb :topic_edit
      else
        denied
      end
    end
########EDIT TOPIC#########
    patch '/topics/:topic_id' do
      if not_empty?(params[:title])
        title = params[:title]
      else
        title = $db.exec_params("SELECT * FROM topics WHERE id = $1",[params[:topic_id]]).first['title']
      end
      if not_empty?(params[:message])
        message = @markdown.render(params[:message])
      else
        message = $db.exec_params("SELECT * FROM topics WHERE id = $1",[params[:topic_id]]).first['message']
      end
      if not_empty?(params[:tag])
        tags = "#{params[:tag]}".gsub(",", "").gsub("#", "")
      else
        tags = $db.exec_params("SELECT * FROM topics WHERE id = $1",[params[:topic_id]]).first['tag']
      end
      $db.exec_params("UPDATE topics SET title = $1, message = $2, tag = $4 WHERE id = $3", [title, message, params[:topic_id], tags])
      redirect "/topics/#{params[:topic_id]}"
    end
  ######DELETE TOPIC######
    delete '/topics/:topic_id' do
      $db.exec_params("DELETE FROM comments WHERE topic_id = $1",[params[:topic_id]])
      $db.exec_params("DELETE FROM topics WHERE id = $1", [params[:topic_id]])
      redirect ('/topics')
    end
###########ADD COMMENT###############
    post '/topics/:topic_id' do
      @topic_id = params[:topic_id]
      if logged_in?
        text = @markdown.render(params[:message])
        @topic = $db.exec_params('SELECT * FROM topics WHERE id = $1', [@topic_id]).first
        @subject = params[:subject]
        @num_comments = $db.exec_params("SELECT count(*) FROM comments WHERE topic_id = $1", [@topic_id]).first["count"]
        user_id = @topic["user_id"]
        @topic_author = $db.exec_params("SELECT * FROM users WHERE id = $1", [user_id]).first["name"]
        @user_img = $db.exec_params("SELECT * FROM users WHERE id = $1", [user_id]).first["img_url"]
        @comments = $db.exec_params("SELECT comments.*, users.name AS comment_author, users.img_url AS author_img FROM comments JOIN users ON users.id = comments.user_id WHERE comments.topic_id = $1", [@topic_id])
        if user_id == current_user
          @edit_topic = "Edit"
        end
        if not_empty?(text)
          $db.exec_params("INSERT INTO comments (subject, message, user_id, topic_id, created_at) VALUES ($1,$2, $3, $4, CURRENT_DATE)", [@subject, text, current_user, @topic_id]);
          redirect "/topics/#{@topic_id}"
        else
          @empty_message = "Don't forget to add the comment"
          erb :topic
        end
      else
        redirect "/topics/#{@topic_id}"
      end
    end
##########EDIT COMMENT PAGE##################
    get '/topics/:topic_id/comments/:comment_id/edit' do
      if logged_in?
        @comment_id = params[:comment_id]
        @topic_id = params[:topic_id]
        @topic = $db.exec_params("SELECT * FROM topics WHERE id = $1", [@topic_id]).first
        @topic_author = $db.exec_params("SELECT users.* FROM users JOIN topics ON topics.user_id = users.id WHERE topics.id = $1",[@topic_id]).first["name"];
        @user_img = $db.exec_params("SELECT users.* FROM users JOIN topics ON topics.user_id = users.id WHERE topics.id = $1",[@topic_id]).first["img_url"];
        @comment = $db.exec_params("SELECT * FROM comments WHERE id = $1", [@comment_id]).first
        erb :comment_edit
      else
        denied
      end
    end
###########EDIT COMMENT#################
    patch '/topics/:topic_id/comments/:comment_id/edit' do
      @topic_id = params[:topic_id]
      @comment_id = params[:comment_id]
      subject = params[:subject]
      text = @markdown.render(params[:message])
      if not_empty?(params[:subject])
         subject = params[:subject]
       else
        subject = $db.exec_params("SELECT * from comments WHERE id = $1", [@comment_id]).first["subject"]
      end
      if not_empty?(text)
        $db.exec_params("UPDATE comments SET subject = $1, message = $2 WHERE id = $3", [subject, text, @comment_id])
        redirect "/topics/#{@topic_id}"
      else
        @empty_message = "Don't forget to add the comment"
        erb :comment_edit
      end
    end
##########DELETE COMMENT##############
    delete '/topics/:topic_id/comments/:comment_id/edit' do
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
      @tag = '%#{params[:topic_tag]}%'
      @topics = $db.exec_params("SELECT topics.*,count(comments.id) AS num_comments FROM topics LEFT JOIN comments ON comments.topic_id = topics.id WHERE topics.tag LIKE $1 GROUP BY topics.id ORDER BY topics.num_votes DESC",['%' + params[:topic_tag] + '%']);
      erb :topics_tag
    end
###########LOG OUT########################
    delete '/users/login' do
      session[:user_id] = nil
      redirect '/index'
    end
############UPVOTE#############
    patch '/topics/:topic_id/upvote' do
      author = $db.exec_params("SELECT user_id FROM topics WHERE id = $1", [params[:topic_id]]).first['user_id']
      if current_user != author
        $db.exec_params("UPDATE topics SET num_votes = (num_votes + 1) WHERE id = $1", [params[:topic_id]])
      end
      redirect  "/topics/#{params[:topic_id]}"
    end
##########DOWN VOTE################
    patch '/topics/:topic_id/downvote' do
      author = $db.exec_params("SELECT user_id FROM topics WHERE id = $1", [params[:topic_id]]).first['user_id']
      if current_user != author
        $db.exec_params("UPDATE topics SET num_votes = (num_votes - 1) WHERE id = $1", [params[:topic_id]])
      end
      redirect  "/topics/#{params[:topic_id]}"
    end

  end
end
