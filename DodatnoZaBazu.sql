use eTicket;
alter schema eTicket default character set utf8 default collate utf8_unicode_ci;

create INDEX SearchIndexAdmin on ADMIN (Firstname,Lastname);

create INDEX SearchIndexPIN_USER on PIN_USER (Firstname,Lastname);

create INDEX SearchNameIndexROUTE on ROUTE (Name);

create INDEX SearchIndexSupervisor on SUPERVISOR (Firstname,Lastname);

alter table PIN_USER alter isActive set default  true;

ALTER TABLE USER MODIFY COLUMN PicturePath varchar(45) default null;
ALTER TABLE USER MODIFY COLUMN DocumentPath1 varchar(50) default null;
ALTER TABLE USER MODIFY COLUMN DocumentPath2 varchar(50) default null;
ALTER TABLE USER MODIFY COLUMN DocumentPath3 varchar(50) default null;



DELIMITER ;;
CREATE PROCEDURE addCredit (in pUserId int, in pAmount decimal(7,2), in pSupervisorId int)
begin

	 declare EXIT handler for  SQLEXCEPTION
        BEGIN
			ROLLBACK;
        
        END;

	if pUserId in ( select Id from USER)  and pSupervisorId in ( select Id from SUPERVISOR)  and pAmount > 0 then
		
        START TRANSACTION;

        set @tempTime = LOCALTIME();
        
         insert into TRANSACTION (Amount,DateAndTime,USER_Id) values (pAmount,@tempTime,pUserId);
         set @tId=  LAST_INSERT_ID();
         if (select Amount,DateAndTime,USER_Id from TRANSACTION where TRANSACTION.Id = @tId)=(pAmount,@tempTime,pUserId) then

			 insert into CREDIT_TRANSACTION values (@tId,pSupervisorId);
             update USER set Credit=Credit+pAmount
             where USER.Id=pUserId;
             
			 COMMIT;
			 else 
			  ROLLBACK;
			 end if;
        
    end if;
end ;;
DELIMITER ;





DELIMITER ;;
CREATE PROCEDURE `addTicketController`(in pPin char(6), in pFirstname varchar(45), in pLastname varchar(45) , in pJMB char(13))
begin
	if pPin not in (select Pin from PIN_USER ) then
		insert into PIN_USER (Pin,Firstname,Lastname,JMB) values (pPin,pFirstName,pLastname,pJMB);
        set @tempId = (select Id from PIN_USER where Pin=pPin);
		insert into TICKET_CONTROLLER(PIN_USER_Id) values (@tempId);
    end if;

end ;;
DELIMITER ;

DELIMITER ;;
CREATE  PROCEDURE `activateTicketController`(in pId int)
begin
	if pId in (select TICKET_CONTROLLER.PIN_USER_Id from TICKET_CONTROLLER)  and 
    (select PIN_USER.isActive from PIN_USER where PIN_USER.Id = pID) = false then
    update PIN_USER set isActive= true where Id=pId;
    end if;
end ;;
DELIMITER ;

delimiter $$
create procedure deactivateTicketController(in pId int)
begin
	if pId in (select TICKET_CONTROLLER.PIN_USER_Id from TICKET_CONTROLLER)  and 
    (select PIN_USER.isActive from PIN_USER where PIN_USER.Id = pID) = true then
    update PIN_USER set isActive= false where Id=pId;
    end if;
end $$



delimiter $$
create procedure addTicketRequest(in pUserId int , in pTicketTypeId int, out pId int)
begin
	declare EXIT handler for  SQLEXCEPTION
        BEGIN
			ROLLBACK;
        END;
	set pId = null;
	if pUserId in (select Id from USER)
     and pTicketTypeId in (select TICKET_TYPE.Id from TICKET_TYPE where TICKET_TYPE.inUSe=true)
     then 	
			START TRANSACTION;
			set @tempTimeDate = localtime();
			insert into TICKET_REQUEST (DateTime,USER_Id,TICKET_TYPE_Id)
			values ( @tempTimeDate,pUserId,pTicketTypeId);
            set pId=  LAST_INSERT_ID();
            if @tempTimeDate=( select DateTime from TICKET_REQUEST where Id=pId) then
            COMMIT;
            else
				ROLLBACK;
			end if;
	end if;
end $$
delimiter ;


delimiter $$
create procedure processTicketResponse(in pTicketResponseID int, out pResult boolean)
begin
	 declare EXIT handler for  SQLEXCEPTION
        BEGIN
			ROLLBACK;
        
        END;
	set pResult =false;
	if pTicketResponseID in (select Id from TICKET_REQUEST_RESPONSE) 
    and (select Approved from TICKET_REQUEST_RESPONSE where Id=pTicketResponseID)=true
    then
		#Postoji TICKET REQUEST
		START TRANSACTION;
			
			set @tempRequestId = (select TICKET_REQUEST_Id from TICKET_REQUEST_RESPONSE where Id= pTicketResponseID );
            set @tempTicketTypeId = (select TICKET_TYPE_Id from TICKET_REQUEST where Id=@tempRequestId );
            set @tempCost =(select Cost from TICKET_TYPE where TICKET_TYPE.Id= @tempTicketTypeId);
            set @tempUserID = (select USER_Id from TICKET_REQUEST where Id = @tempRequestId);
            set @tempUserCredit =(select Credit from USER where USER.Id=@tempUserID);
            if @tempUserCredit >= @tempCost
             then 
			
				 #KORISNIK IMA DOVOLJNO KREDITA
				 set @tempTime = LOCALTIME();
				 insert into TRANSACTION (Amount,DateAndTime,USER_Id) values (@tempCost,@tempTime,@tempUserID);
				 set @tId=  LAST_INSERT_ID();
				 if (select Amount,DateAndTime,USER_Id from TRANSACTION where Id = @tId)=(@tempCost,@tempTime,@tempUserID) 
					 then
						
						 insert into TICKET_TRANSACTION values (@tId,pTicketResponseID);
						 update USER set Credit=Credit-@tempCost
                         where USER.Id=@tempUserID;
                         if @tempTicketTypeId in (select TICKET_TYPE_Id from PERIODIC_TICKET) then 
         
								set @tempValidUntil =
                                LOCALTIME() + interval
                                (select ValidFor from PERIODIC_TICKET where TICKET_TYPE_Id = @tempTicketTypeId ) day;
								insert into USER_TICKETS values (@tempUserID,@tId,@tempValidUntil,null,@tempTicketTypeId);
                                set pResult =true;
						 elseif @tempTicketTypeId in (select TICKET_TYPE_Id from AMOUNT_TICKET) 
                         then 	
								set @tempAmount = (select Amount from AMOUNT_TICKET where TICKET_TYPE_Id = @tempTicketTypeId );
								insert into USER_TICKETS values (@tempUserID,@tId,null,@tempAmount,@tempTicketTypeId);
                                set pResult =true;
						 else 
							ROLLBACK;
                         end if;
					else ROLLBACK;
					end if;
                 

				
            
            end if;
			COMMIT;
   
    end if;
    
end$$
delimiter ;


delimiter $$
create procedure addScanTransaction(in pAmount decimal(7,2), in pUserId int, in pTerminalID int)
BEGIN
	declare EXIT handler for  SQLEXCEPTION
        BEGIN
		

    ROLLBACK;
        
        END;
	if pUserId in ( select Id from USER) and pTerminalID in (select Id from TERMINAL)
    then
	START TRANSACTION;
	INSERT INTO TRANSACTION (Amount,DateAndTime,USER_Id)
	values (pAmount,localtime(),pUserId);
	set @tId=  LAST_INSERT_ID();

    INSERT INTO SCAN_TRANSACTION (TRANSACTION_Id,TERMINAL_Id) values (@tId,pTerminalID);
    update USER
    set Credit=Credit-pAmount
    where USER.Id = pUserId;
    COMMIT;
	end if;
END$$
delimiter ;

call processTicketResponse(7,@pero);
select @pero;
###AddUser AddSupervisor AddAdmin Activate Deactivate Admin Supervisor

###Pogledi
