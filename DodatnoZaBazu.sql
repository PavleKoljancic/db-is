use eTicket;
alter schema eTicket default character set utf8 default collate utf8_unicode_ci;

create INDEX SearchIndexAdmin on ADMIN (Firstname,Lastname);

create INDEX SearchIndexPIN_USER on PIN_USER (Firstname,Lastname);

create INDEX SearchNameIndexROUTE on ROUTE (Name);

create INDEX SearchIndexSupervisor on SUPERVISOR (Firstname,Lastname);

create INDEX TransactionDateTimeIndex on TRANSACTION (DateAndTime);

alter table PIN_USER alter isActive set default  true;