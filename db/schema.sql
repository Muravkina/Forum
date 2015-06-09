-- DROP DATABASE IF EXISTS forum;
-- CREATE DATABASE forum;


CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  email VARCHAR NOT NULL,
  password VARCHAR NOT NULL,
  img_url VARCHAR DEFAULT '/img/user_icon.png'
);

CREATE TABLE topics (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  title VARCHAR NOT NULL,
  message TEXT NOT NULL,
  num_votes INTEGER DEFAULT 0,
  created_at DATE,
  tag VARCHAR
);

CREATE TABLE comments (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  topic_id INTEGER REFERENCES topics(id),
  created_at DATE,
  subject VARCHAR NOT NULL,
  message TEXT NOT NULL
);
