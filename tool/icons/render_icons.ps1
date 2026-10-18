# 앱 아이콘 원본(assets/icon/app_icon.svg)과 같은 모양으로 PNG를 다시 그린다.
# 저장소 루트에서: powershell -ExecutionPolicy Bypass -File tool\icons\render_icons.ps1
# 모양을 바꾸면 app_icon.svg, res/drawable의 벡터, lib/shared/widgets/app_logo.dart도 같이 고친다.
Add-Type -AssemblyName System.Drawing

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$res = Join-Path $root 'android\app\src\main\res'
$out = Join-Path $root 'assets\icon'

$orange = [System.Drawing.Color]::FromArgb(255, 255, 77, 0)
$ink = [System.Drawing.Color]::FromArgb(255, 17, 17, 17)
$muted = [System.Drawing.Color]::FromArgb(255, 102, 102, 102)
$font = 'Malgun Gothic'

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

# (x, y)에 한 변 size인 아이콘을 그린다. -Square면 모서리를 깎지 않는다(Play 스토어가 직접 깎는다).
function DrawIcon($g, [float]$x, [float]$y, [float]$size, [switch]$Square) {
  $state = $g.Save()
  $g.TranslateTransform($x, $y)
  $g.ScaleTransform($size / 108, $size / 108)
  $bg = New-Object System.Drawing.SolidBrush $orange
  if ($Square) { $g.FillRectangle($bg, 0, 0, 108, 108) } else { $g.FillPath($bg, (RoundRect 0 0 108 108 24)) }

  $arc = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 8
  $arc.StartCap = 'Round'; $arc.EndCap = 'Round'
  $g.DrawArc($arc, 24, 38, 60, 60, 180, 180)

  $needle = New-Object System.Drawing.Pen $ink, 6
  $needle.StartCap = 'Round'; $needle.EndCap = 'Round'
  $g.DrawLine($needle, 54, 68, 68, 46)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $ink), 47, 61, 14, 14)

  $bar = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(140, 255, 255, 255))
  $g.FillPath($bar, (RoundRect 30 80 48 6 3))
  $g.Restore($state)
}

function NewCanvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.PixelOffsetMode = 'HighQuality'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  return @($bmp, $g)
}

function SaveCanvas($bmp, $g, [string]$path) {
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output $path
}

function DrawText($g, [string]$text, [float]$size, [System.Drawing.FontStyle]$style, $color, [float]$x, [float]$y) {
  $f = New-Object System.Drawing.Font $font, $size, $style, ([System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($text, $f, (New-Object System.Drawing.SolidBrush $color), $x, $y)
}

# 안드로이드 8 미만 런처 아이콘
$sizes = [ordered]@{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($k in $sizes.Keys) {
  $s = $sizes[$k]
  $bmp, $g = NewCanvas $s $s
  $g.Clear([System.Drawing.Color]::Transparent)
  DrawIcon $g 0 0 $s
  SaveCanvas $bmp $g (Join-Path $res "mipmap-$k\ic_launcher.png")
}

# Play 스토어 앱 아이콘 512x512 (모서리 없음)
$bmp, $g = NewCanvas 512 512
DrawIcon $g 0 0 512 -Square
SaveCanvas $bmp $g (Join-Path $out 'play_store_icon_512.png')

# Play 스토어 그래픽 이미지 1024x500
$bmp, $g = NewCanvas 1024 500
$g.Clear([System.Drawing.Color]::White)
DrawIcon $g 90 140 220
DrawText $g '매일재라' 80 Bold $ink 350 156
DrawText $g '친구 그룹과 하루 기록을 함께 보는 다이어트 앱' 26 Regular $muted 356 272
SaveCanvas $bmp $g (Join-Path $out 'play_feature_graphic.png')

# 초대 링크 공유 미리보기(Open Graph) 1200x630
$bmp, $g = NewCanvas 1200 630
$g.Clear([System.Drawing.Color]::White)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $orange), 0, 0, 1200, 12)
DrawIcon $g 100 175 280
DrawText $g '매일재라 그룹에' 72 Bold $ink 440 170
DrawText $g '초대받았어요' 72 Bold $orange 440 262
DrawText $g '초대 코드로 들어와 하루 기록을 함께 봐요' 32 Regular $muted 446 384
SaveCanvas $bmp $g (Join-Path $out 'og_invite.png')
