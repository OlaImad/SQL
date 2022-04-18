--- We have a list of all the reserve changes for each claim, but we need the total sum of reserve changes separated
--- by the 5 reserve type buckets we are using 
--- We only need to keep the claim in the result if at least one of the following is true
--- 1- The claim type is either Medical-only  or First Aid
--- 2- The examiner is in San Diego and the total reserve amount on the claim is greater than the examiner's reserve limit.
--- 3- The examiner is either in Scaramento or San Francisco and at least one of:
--- A- The total Medical Reserve (reserve Bucket 1) is greater than 800
--- B- The Total expense Reserve (reserve Bucket 5) is greater than 100
--- c- There are positive reserves in any of the remaining reserve buckets (TD, PD, Rehab)
select pivottable.*
from
	(
	select 
		claim.ClaimNumber,
		(CASE 
			WHEN ReserveType.ParentID IN (1, 2, 3, 4, 5) then ReserveType.ParentID
			ELSE ReserveType.reserveTypeID
			END) AS ReserveTypeBucketID,
		Reserve.ReserveAmount,
		Office.OfficeDesc,
		users.UserName as ExaminerCode,
		users2.UserName as SupervisorCode,
		users3.UserName as ManagerCode,
		users.title as ExaminerTitle,
		users2.title as SupervisorTitle,
		users3.title as ManagerTitle,
		users.lastfirstname as Examinername,
		users2.lastfirstname as Supervisorname,
		users3.lastfirstname as Managername,
		ClaimStatus.ClaimStatusDesc,
		Patient.LastName +', '+ TRIM (Patient.firstname  +' ' +Patient.middlename) as ClaimantName, 
		Claimant.ReopenedDate,
		ClaimantType.ClaimantTypeDesc,
		office.State,
		users.ReserveLimit
	

	from Claimant
	inner join claim on claim.ClaimID = Claimant.ClaimID
	inner join users on users.UserName = claim.ExaminerCode
	inner join users  users2 on users.Supervisor = users2.username
	inner join users users3 on users2.Supervisor = users3.UserName
	inner join office on users.OfficeID= Office.officeid
	inner join ClaimantType on ClaimantType.ClaimantTypeID = Claimant.ClaimantTypeID
	inner join Reserve on Reserve.ClaimantID = Claimant.claimantid
	left join ClaimStatus on ClaimStatus.ClaimStatusID = Claimant.claimStatusID
	left join ReserveType on ReserveType.reserveTypeID = Reserve.ReserveTypeID
	left join patient on Patient.PatientID = Claimant.PatientID
	where Office.OfficeDesc in ('san francisco', 'san diego', 'sacramento')
		and (ReserveType.ParentID in (1, 2, 3, 4, 5) or ReserveType.reserveTypeID in (1, 2, 3, 4, 5))
		and (ClaimStatus.ClaimStatusID = 1 or (ClaimStatus.ClaimStatusID = 2 and claimant.reopenedreasonid  <> 3 ))
	 
	) BaseData

PIVOT (  
		sum(reserveamount)
		FOR ReserveTypeBucketID in ([1],[2], [3], [4], [5])
		) pivottable
inner join claim on Claim.ClaimNumber = pivottable.ClaimNumber
inner join Claimant on Claimant.ClaimID = claim.ClaimID
where pivottable.ClaimantTypeDesc = 'First Aid' or ClaimantTypeDesc = 'Medical Only'
	or 
	(OfficeDesc = 'san diego' and ISNULL([1], 0) + ISNULL([2], 0) +ISNULL([3], 0) +ISNULL([4], 0) +ISNULL([5], 0) >= pivottable.ReserveLimit)
	or 
	(pivottable.OfficeDesc in ('sacramento', 'san francisco')
	and (ISNULL([1],0) > 800
		or ISNULL([5],0) > 100
		or ISNULL([2],0)  + ISNULL([3], 0) + ISNULL([4], 0) > 0) )
# ---------------------------------------------------------------------------------------------------------------

--- which offices has the most users
select Office.OfficeDesc as office, count(users.UserName) as user_count
from office 
left join users
on Office.OfficeID = users.OfficeID
group by office.officedesc
order by count(users.UserName) desc

--- select all the reserve changes made by a user in San Francisco

select enteredby, count(enteredby) as reserve_changes
from Reserve
where enteredby in 
(select users.UserName
from users
join office on users.OfficeID = Office.OfficeID and Office.OfficeID = 1)
group by EnteredBy
-- OR 
select Office.OfficeDesc, Reserve.*
from reserve
join users
on Reserve.EnteredBy = users.UserName
join Office
on Users.OfficeID = Office.OfficeID
where Office.OfficeDesc = 'san francisco'

# ------------------------------------------------------------------------------------------------------------------
-- Reserve table we want a column showing the total reserve amount next to the reserve amount column 
select c.ClaimNumber, R.ReserveAmount, reservesum.TotalReserveAmount,
		ReserveAmount/TotalReserveAmount as reserveproportion
from 
	(
	select cl2.claimantid, sum(R2.reserveamount) as TotalReserveAmount
	from reserve R2
	inner join Claimant CL2 on CL2.ClaimantID = R2.ClaimantID
	inner join claim C2 on CL2.claimID = c2.claimID
	where c2.ClaimNumber = '500008648-1'  
	group by cl2.ClaimantID
	) reservesum

inner join reserve R on reservesum.ClaimantID = R.claimantID
inner join Claimant CL on CL.ClaimantID = R.ClaimantID
inner join claim C on CL.claimID = c.claimID
where c.ClaimNumber = '500008648-1' 

--- get the current examiner and assigned date for every claim 
select ClaimLog.pk	as ClaimID, 
		ClaimLog.NewValue as CurrentExaminer,
		x.LatestAssignmentDate as  AssignedDate
from (
	 select pk, max(EntryDate) as LatestAssignmentDate
	 from ClaimLog
	 where FieldName = 'examinercode'
	 group by pk
	 ) x 
inner join ClaimLog on x.pk = claimlog.PK and x.LatestAssignmentDate = ClaimLog.EntryDate and ClaimLog.FieldName = 'examinercode'
order by ClaimLog.pk
# ------------------------------------------------------------------------------------------------------------------
select c.ClaimNumber, R.ReserveAmount, 
		(
	select sum(R2.reserveamount) 
	from reserve R2
	inner join Claimant CL2 on CL2.ClaimantID = R2.ClaimantID
	inner join claim C2 on CL2.claimID = c2.claimID
	where c2.ClaimNumber = '500008648-1'  
	group by cl2.ClaimantID
	) as totalreserveamount
from reserve R 
inner join Claimant CL on CL.ClaimantID = R.ClaimantID
inner join claim C on CL.claimID = c.claimID
where c.ClaimNumber = '500008648-1' 
# ---------------------------------------------------------------------------------------------------------------------
-- for each claim, compare the medical reserving amount in the reserving tool between the first publish and the last publish

select sub.*, rt1.MedicalReservingAmount as firstmedicalamount, rt2.MedicalReservingAmount as secondmedicalamount
from
(select rt_first.ClaimNumber,
firstpublishdate,
lastpublishdate
from (
	select ClaimNumber, min(EnteredOn) as firstpublishdate
	from ReservingTool
	where IsPublished = 1
	group by ClaimNumber) rt_first
inner join (
	select ClaimNumber, max(EnteredOn) as lastpublishdate
	from ReservingTool
	where IsPublished = 1
	group by ClaimNumber) rt_last
on rt_last.ClaimNumber = rt_first.ClaimNumber
) sub
inner join ReservingTool rt1 on rt1.ClaimNumber = sub.ClaimNumber and rt1.EnteredOn = sub.firstpublishdate and rt1.IsPublished = 1
inner join ReservingTool rt2 on rt2.ClaimNumber = sub.ClaimNumber and rt2.EnteredOn = sub.lastpublishdate and rt2.IsPublished = 1

-- USING OVER
select sub.*, rt1.MedicalReservingAmount as firstmedicalamount, rt2.MedicalReservingAmount as secondmedicalamount
from
(
select distinct ClaimNumber,
min(enteredon) over (partition by claimnumber) as firstpublishdate,
max(EnteredOn) over (partition by claimnumber) as lastpublishdate
from ReservingTool 
where ispublished = 1
 ) sub
inner join ReservingTool rt1 on rt1.ClaimNumber = sub.ClaimNumber and rt1.EnteredOn = sub.firstpublishdate and rt1.IsPublished = 1
inner join ReservingTool rt2 on rt2.ClaimNumber = sub.ClaimNumber and rt2.EnteredOn = sub.lastpublishdate and rt2.IsPublished = 1
order by ClaimNumber
# --------------------------------------------------------------------------------------------------------------------
select minimumdate.claimnumber,
		minimumdate.firstpublishdate,
		maximumdate.lastPublishDate,
		DATEDIFF(day, minimumdate.firstpublishdate, maximumdate.lastPublishDate) as difference
		from 
(select ClaimNumber,
min(EnteredOn) as FirstPublishDate
from ReservingTool
where IsPublished = 1
group by ClaimNumber
) minimumdate
join (select ClaimNumber,
max(EnteredOn) as lastPublishDate
from ReservingTool
where IsPublished = 1
group by ClaimNumber
) maximumdate
on minimumdate.ClaimNumber = maximumdate.ClaimNumber
order by difference desc
# --------------------------------------------------------------------------------------------------------------------
--- Variables and Table Variables 

DECLARE @AsOfDate date
set @AsOfDate = '1/1/2019'

DECLARE @RservingToolPbl TABLE (
	ClaimNumbers varchar (30),
	LastPublishedDate datetime
	)
DECLARE @AssignedDateLog TABLE (
	ClaimId int,
	ExaminerAssignedDate datetime
	)

  #  ----------------------------------------------------------------------------------------------------------
  --- Temporary Tables

  
DECLARE @temp_reserve_tbl TABLE (
	claimnumber varchar(30),
	TotalReserveAmount float,
	patientname varchar (255)
	)

insert into @temp_reserve_tbl 
select 
	claim.ClaimNumber,
	sum(reserve.reserveamount) as ReserveSum, 
	TRIM(Patient.lastname + ' ' +patient.firstname + ' '+patient.middlename) as PatientName

from claim join Claimant on claim.ClaimID = Claimant.ClaimID
join Reserve on Reserve.ClaimantID = Claimant.ClaimantID
join Patient on Patient.PatientID = Claimant.PatientID
group by 	claim.ClaimNumber, TRIM(Patient.lastname +' '+patient.firstname +' '+patient.middlename)   

# --------------------------------------------------------------------------------------------------------------

CREATE TABLE MedicalReserveCases1 (
	ReservingToolId int foreign key references ReservingTool(ReservingToolId),
	ClaimNumber varchar(30),
	WorstCaseMedicalReserve float
	)

insert into MedicalReserveCases1 
	select 
		ReservingTool.ReservingToolID,
		ReservingTool.ClaimNumber,
		ReservingTool.MedicalReservingAmount * 2 as WorstCaseMedicalReserve 
		-- OR WorstCaseMedicalReserve = ReservingTool.MedicalReservingAmount * 2 

		from ReservingTool
select *  from MedicalReserveCases1

# ---------------------------------------------------------------------------------------------------------------

-- update MedicalReserveCases Add the column Best case medical reserve ( half worst case medical reserve)

select * , (case
when worstcasemedicalreserve = 0 then 0
else worstcasemedicalreserve / 2
end) as BestCaseMedicalReserve
from MedicalReserveCases1
-- OR this way to make permanent 
ALTER TABLE Medicalreervecases1
add BestCaseMedicalReserve float 

update MedicalReserveCases1
set Bestcasemedicalreserve  = MedicalReservingAmount * 0.5
from MedicalReserveCases
inner join ReservingTool
on  MedicalReserveCases1.ReservingToolId = ReservingTool.ReservingToolID
# ---------------------------------------------------------------------------------------------------------------

--- set every record with a NULL value for [entering grade level 1] field to 1

SELECT * FROM [G&T Results 2017-18]
UPDATE [G&T Results 2017-18]
SET [Entering Grade Level] = 1 WHERE [Entering Grade Level] IS NULL

--  For every student that got a 99 on [overall score] and has not yet been assigned a school, assign them to their first choice school
-- here assumed that the school preference only contains one school
UPDATE [G&T Results 2017-18]
SET [School Assigned] = [School Preferences]
WHERE [School Assigned] IS NULL AND [Overall Score] >= 99
-- here school preference contains more than one school seperated by , or /
--setp  one 
update [G&T Results 2017-18]
set [School Preferences] = REPLACE([School Preferences], '/',',')
-- step 2 - CHARINDEX FUNCTION 
select 
	[School Preferences],
	CHARINDEX(',', [School Preferences], 1) as CommaIndex,
	(CASE WHEN CHARINDEX(',', [School Preferences], 1) = 0 then [School Preferences]
		ELSE left([School Preferences], CHARINDEX(',', [School Preferences], 1) -1 ) END ) as PreferredSchool
from [G&T Results 2017-18]
--step 3
update [G&T Results 2017-18]
set [School Assigned] =	(CASE WHEN CHARINDEX(',', [School Preferences], 1) = 0 then [School Preferences]
							ELSE left([School Preferences], CHARINDEX(',', [School Preferences], 1) -1 ) END ) 
where [Overall Score] = 99 and ([School Assigned] is null or TRIM([School Assigned]) = 'none')

--- delete all of the NULL rows from [update].[dbo].G&T Results 2018-19]
SELECT * FROM [G&T Results 2018-19]
delete from [G&T Results 2018-19]
where Timestamp is null

---Insert a new reserve type record in the fatality reserve type bucket
select * from ReserveType
insert into ReserveType 
values (1, '','fatality misc',10)

--- --- Declare a table variable @lagestclaimsinreservingtool and populate it with the 5 largest total reserve amounts for 
--- publishes in [dbo].[resering tool]


DECLARE @LargestClaimsInReservingTool TABLE (
	ReservingToolId int,
	ClaimNumber varchar (30),
	publishedDate datetime,
	TotalReservingAmount float
	)
	
	insert into @LargestClaimsInReservingTool
select TOP 5
	ReservingToolID,
	ClaimNumber,
	EnteredOn as PublishedDate,
	MedicalReservingAmount+TDReservingAmount+PDReservingAmount+ExpenseReservingAmount as TotalReservingAmount
from ReservingTool
	WHERE IsPublished = 1
	order by TotalReservingAmount desc
	

select * from @LargestClaimsInReservingTool

--- Declare a temporary table #TotalIncurredTable and populate it with the sum of all the reserve amounts from [dbo].[reserve] for each claim
--- include columns -claimaintid -claimnumber -totalincurredamount
CREATE TABLE #TotalIncurredTable (
	claimantId int primary key,
	claimnumber varchar (30),
	totalincurredamount float
	)
select * from #TotalIncurredTable
insert into #TotalIncurredTable 
select
	claimant.ClaimantID,
	claim.ClaimNumber,
	sum(reserve.reserveamount) as TotalIncurredAmount
from reserve
join Claimant on Reserve.ClaimantID = Claimant.ClaimantID
join claim on Claim.ClaimID = Claimant.ClaimID 
group by claimant.ClaimantID, claim.ClaimNumber 
ORDER BY Claimant.ClaimantID
DROP TABLE #TotalIncurredTable