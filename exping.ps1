# exping.ps1
# ローカルネットワーク内のアクティブデバイス検出スクリプト

# ネットワークのプレフィックスを取得（通常は192.168.1など）
$ipConfig = Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne "Disconnected"}
$ipAddress = $ipConfig.IPv4Address.IPAddress
$prefix = $ipAddress -replace "\.\d+$", ""

Write-Host "ネットワークスキャンを開始します: $prefix.0/24"
Write-Host "-------------------------------------"

# 進捗状況を表示するための変数
$total = 254
$current = 0
$found = 0

# 結果を格納する配列
$activeHosts = @()

# 1〜254の各IPアドレスに対してPingを実行
1..254 | ForEach-Object {
    $ip = "$prefix.$_"
    $current++
    
    # 進捗状況をパーセントで表示
    $progress = [math]::Round(($current / $total) * 100)
    Write-Progress -Activity "ネットワークスキャン中" -Status "$progress% 完了" -PercentComplete $progress
    
    # Ping実行（古いバージョンにも対応）
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($ping) {
        $found++
        
        # ホスト名を取得（可能な場合）
        try {
            $hostname = [System.Net.Dns]::GetHostEntry($ip).HostName
        } catch {
            $hostname = "不明"
        }
        
        # MACアドレスを取得（可能な場合）
        $arp = Get-NetNeighbor -IPAddress $ip -ErrorAction SilentlyContinue
        $mac = if ($arp.LinkLayerAddress) { $arp.LinkLayerAddress } else { "不明" }
        
        # 結果を配列に追加
        $activeHosts += [PSCustomObject]@{
            IPアドレス = $ip
            ホスト名 = $hostname
            MACアドレス = $mac
        }
        
        # 即時に結果を表示
        Write-Host "デバイスを発見: $ip (ホスト名: $hostname, MAC: $mac)"
    }
}

Write-Progress -Activity "ネットワークスキャン中" -Completed

# 結果をまとめて表示
Write-Host ""
Write-Host "スキャン完了！ $found 台のデバイスが見つかりました"
Write-Host "-------------------------------------"
$activeHosts | Format-Table -AutoSize

# デスクトップのパスを取得
$desktopPath = [Environment]::GetFolderPath("Desktop")

# 結果をCSVファイルに保存（デスクトップに）
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvPath = "$desktopPath\NetworkScan-$timestamp.csv"
$activeHosts | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "結果を保存しました: $csvPath"
