/*
1. After it has been created, go to the Storage Account in the Azure portal. The Synapse Workspace (search for Synapse workspace name) must have 
	"Storage Blob Data Reader" and "Storage Blob Data Contributor" IAM Roles.

2. For AAD user rights:
  a. Create AAD group/user in Microsoft Entra ID, add members (if aad group) and copy name
  b. Go to the storage account in the Azure portal.  The AAD Group/User from 2.a must have storage blob data reader IAM role.
  c. Go to the Azure Synapse Analytics in Azure portal:
		i.The AAD Group/User from 2a. must have Contributor IAM Role.
		ii.Click "Open Synapse Studio".  Once in the Studio, click "Manage" (briefcase icon) and Click Access Control.  Add Synapse Administrator for user/group.


3. The script below to add an AAD user/group login for synapse serverles must be ran by Microsoft Entra ID admin -  
	found by going to "Microsoft Entra ID" under settings in Synapse Workspace
	
4.  Check user access:
SELECT r.name role_principal_name, m.name AS member_principal_name
FROM sys.database_role_members rm
JOIN sys.database_principals r
ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m
ON rm.member_principal_id = m.principal_id

--GRANT SELECT,UPDATE,INSERT,DELETE ON <table> TO [user];
--exec sp_droprolemember [db_datawriter], [svc-commapp]
*/

use master
go
CREATE CREDENTIAL [https://<storage account name>.dfs.core.windows.net/<dataverse container>]
WITH IDENTITY = 'Managed Identity';

use master
go	
CREATE LOGIN [<AAD Group/AAD User>] FROM EXTERNAL PROVIDER;

use <database>
go
CREATE USER [<AAD Group/AAD User>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<AAD Group/AAD User>];

--4. For adding a SQL user to Synapse Serverless. 


CREATE LOGIN <SqlLoginName> WITH PASSWORD = '';
GO

use <database>
go
CREATE USER <SqlLoginName> FOR LOGIN <SqlLoginName>;
GO

ALTER ROLE db_datareader ADD MEMBER <SqlLoginName>; 
GO

----** This command allows the SQL user to access the referenced credential/storage account.
USE MASTER
GO
GRANT ALTER ANY CREDENTIAL TO 
<SqlLoginName/AAD User/AAD Group>
