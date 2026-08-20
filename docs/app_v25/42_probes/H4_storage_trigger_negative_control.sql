begin;
delete from storage.objects where bucket_id = '__no_such_bucket__';
rollback;
