-- Reference data only: communities are content, not fake users.
-- Run after 0001_init.sql. Safe to re-run.

insert into public.joints (slug, description) values
  ('TechNaija',   'Gadgets, startups, dev talk and Naija tech gist'),
  ('KadunaHustle','Side hustles, markets and grind in Kaduna'),
  ('JosConnect',  'Plateau people, events and community updates'),
  ('PremierLeague','Football banter, match threads and hot takes'),
  ('JapaGist',    'Visa routes, IELTS, jobs abroad and honest stories'),
  ('NaijaMusic',  'Afrobeats, amapiano, new drops and throwbacks'),
  ('CampusLife',  'UNIJOS, UI, ABU, UNILAG and every campus in between'),
  ('SmallMoney',  'Saving, side income and personal finance for young Nigerians')
on conflict (slug) do nothing;
