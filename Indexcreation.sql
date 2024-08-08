SET NOCOUNT ON;
print 'Put system in Maintainance mode'
print ''
UPDATE SQLSYSTEMVARIABLES SET VALUE = 1 WHERE PARM = 'CONFIGURATIONMODE'
SET NOCOUNT OFF;


DECLARE @SchemaName NVARCHAR(MAX) = 'dbo';
DECLARE @TableId INT;
DECLARE @TableName NVARCHAR(250);
DECLARE @SQLStmt NVARCHAR(MAX);
DECLARE @SlNo INT = 0;


DECLARE Table_cursor CURSOR LOCAL FOR
SELECT T.ID, T.Name
FROM TABLEIDTABLE T
WHERE T.Name in (
SELECT PHYSICALTABLENAME AS TableName FROM AIFSQLROWVERSIONCHANGETRACKINGENABLEDTABLES
UNION SELECT REFTABLENAME AS TableName FROM BUSINESSEVENTSDEFINITION WHERE CHANNEL LIKE 'AthenaFinanceOperationsTableDa%'
)

-- if the concerned tables are not in the above list, then replace the above cursor query with following cursor query
-- DECLARE Table_cursor CURSOR LOCAL FOR
-- SELECT T.ID, T.Name
-- FROM TABLEIDTABLE T
-- WHERE T.Name in ( 'TableName1', 'TableName2', .....)

OPEN Table_cursor;
FETCH NEXT FROM Table_cursor INTO @TableId, @TableName;
WHILE @@FETCH_STATUS = 0
BEGIN
	BEGIN TRY
		BEGIN TRAN
			BEGIN
				-- Script timeout in milliseconds
				SET LOCK_TIMEOUT 1000;
				SET @SlNo = @SlNo + 1;

				-- Add SYSROWVERSION index
				IF NOT EXISTS (SELECT TOP 1 1
					FROM sys.indexes i
					INNER JOIN sys.index_columns ic ON ic.index_id = i.index_id AND ic.object_id = i.object_id
					INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
					INNER JOIN sys.tables t ON t.object_id = c.object_id
					INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
					WHERE s.name = @SchemaName AND ic.index_column_id = 1 AND ic.is_included_column = 0 AND t.name = @TableName AND c.name = 'SYSROWVERSION'
					)
				BEGIN
					SET @SQLStmt = '
					CREATE NONCLUSTERED INDEX AIF_I_' + CAST(@TableId as nvarchar) + 'SQLROWVERSIONIDX
					ON ' + @SchemaName + '.' + @TableName + ' ([SYSROWVERSION] ASC)
					WITH (ONLINE = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = ON)
					ON [PRIMARY]
					';
					EXEC sp_executesql @SQLStmt;
				END

				-- Add RECID index
				IF NOT EXISTS (SELECT TOP 1 1
					FROM sys.indexes i
					INNER JOIN sys.index_columns ic ON ic.index_id = i.index_id AND ic.object_id = i.object_id
					INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
					INNER JOIN sys.tables t ON t.object_id = c.object_id
					INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
					WHERE s.name = @SchemaName AND ic.index_column_id = 1 AND ic.is_included_column = 0 AND t.name = @TableName AND c.name = 'RECID'
					)
				BEGIN
					SET @SQLStmt = '
					CREATE NONCLUSTERED INDEX AIF_I_' + CAST(@TableId as nvarchar) + 'RECIDDATASYNCIDX
					ON ' + @SchemaName + '.' + @TableName + ' ([RECID] ASC)
					WITH (ONLINE = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = ON)
					ON [PRIMARY]
					';
					EXEC sp_executesql @SQLStmt;
				END

				SET LOCK_TIMEOUT 0;
			END
		COMMIT TRAN
		print cast(@SlNo as nvarchar) + '. ' + @SchemaName + '.' + @TableName + '(' + cast(@TableId as nvarchar) + ') => succeeded'
	END TRY
	BEGIN CATCH
		print cast(@SlNo as nvarchar) + '. ' + @SchemaName + '.' + @TableName + '(' + cast(@TableId as nvarchar) + ') => SQL error[' + cast(ERROR_NUMBER() as nvarchar) + '] : ' + ERROR_MESSAGE()
		ROLLBACK TRAN
	END CATCH
	FETCH NEXT FROM Table_cursor INTO @TableId, @TableName;
END

CLOSE Table_cursor
DEALLOCATE Table_cursor

SET NOCOUNT ON;
print ''
print 'Put system out of Maintainance mode'
UPDATE SQLSYSTEMVARIABLES SET VALUE = 0 WHERE PARM = 'CONFIGURATIONMODE'
SET NOCOUNT OFF;

print ''
print 'Finished'