\c forum

TRUNCATE TABLE users, topics, comments RESTART IDENTITY;

INSERT INTO users
  (name, email, password)
VALUES
  ('Dasha Murauyova', 'muravkina@yahoo.com', 'password'),
  ('Ilia Gerassimov', 'geril@hotmail.com', 'password'),
  ('Greg Wignant', 'gregory@gmail.com', 'password'),
  ('Alex Wong', 'awong@gmail.com', 'password'),
  ('Mila Kunis', 'mkunnis@gmail.com', 'password'),
  ('Fernando Rodriguez', 'fernando@gmail.com', 'password')
;

INSERT INTO topics
  (user_id, title, message, created_at, tag)
VALUES
  (1, 'Environment', 'The environment is where we all meet; where all have a mutual interest; it is the one thing all of us share.',  CURRENT_DATE, '#earth, #LadyBirdJohnson'),
  (2, 'Natures heart', 'Keep close to Nature’s heart… and break clear away, once in awhile, and climb a mountain or spend a week in the woods. Wash your spirit clean', CURRENT_DATE, '#earth, #nature'),
  (3, 'A world is not given', 'A true conservationist is a man who knows that the world is not given by his fathers, but borrowed from his children.', CURRENT_DATE,  '#nature, #world'),
  (4, 'Live Now', 'Live in each season as it passes; breathe the air, drink the drink, taste the fruit, and resign yourself to the influence of each.', CURRENT_DATE, '#LiveNow, #earth'),
  (5, 'Nature', 'We need the tonic of wildness—to wade sometimes in marshes where the bittern and the meadow-hen lurk, and hear the booming of the snipe; to smell the whispering sedge where only some wilder and more solitary fowl builds her nest, and the mink crawls with its belly close to the ground. At the same time that we are earnest to explore and learn all things, we require that all things be mysterious and unexplorable, that land and sea be infinitely wild, unsurveyed and unfathomed by us because unfathomable. We can never have enough of nature.', CURRENT_DATE, '#nature'),
  (6, 'Every walk', 'In every walk with nature one receives far more than he seeks.', CURRENT_DATE, '#LiveNow')
;
