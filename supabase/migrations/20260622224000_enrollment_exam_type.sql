-- The roadmap setup now drops the coaching + exam-date pickers and keeps only
-- the exam track (JEE/NEET) + daily study hours, persisting them server-side so
-- the (deferred) AI generator can read the student's pace and target. The table
-- already carries daily_minutes/exam_date/current_position; it lacked the exam
-- track, so add it. Additive, non-breaking (defaults to 'jee').
alter table public.student_enrollment
  add column if not exists exam_type text not null default 'jee';

comment on column public.student_enrollment.exam_type is
  'Exam track: ''jee'' | ''neet''. Drives the chapter set (math vs bio) and the '
  'fixed exam date used when pacing the roadmap.';
