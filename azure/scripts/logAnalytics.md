# Resource Graph Explorer
Access methods:
- Azure portal
- CLI (preferred)

```
# Example (first time will install extension resource-graph)
az graph query -q 'Resources | project name, type | order by name asc | limit 5'
```

### Sources
- 

# Grafana
Some queries:
```
Subscriptions()
ResourceGroups()
```

### Sources
- [Datasource](https://grafana.com/grafana/plugins/grafana-azure-monitor-datasource/)

# Log Analytics
Some queries:
```
AzureDiagnostics 
| where OperationName == "ApplicationGatewayAccess"

AzureDiagnostics 
| where  ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog" and action_s == "Blocked"
| order by TimeGenerated asc

AzureDiagnostics 
| where  ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
// | where TimeGenerated between (datetime(2021-09-12) .. datetime(2021-09-13))
| where TimeGenerated >= datetime(2021-09-12) and TimeGenerated <= datetime(2021-09-13)
| order by TimeGenerated asc

AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
 and action_s == "Detected"
// | where TimeGenerated >= $__timeFrom() and TimeGenerated <= $__timeTo()
| summarize count() by clientIp_s, bin(TimeGenerated, 1h)

```

### Sources
- [Log Analytics tutorial](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-tutorial)
- [AzureDiagnostics](https://docs.microsoft.com/en-us/azure/azure-monitor/reference/tables/AzureDiagnostics)
- [Kusto query overview](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)