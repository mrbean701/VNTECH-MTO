# md-to-docx.ps1 -- chuyen .md -> .docx bang Open XML (KHONG can Microsoft Word)
param([string]$Name)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "docs\$Name.md"
$docx = Join-Path $root "docs\$Name.docx"
if (-not (Test-Path -LiteralPath $src)) { throw "Khong thay: $src" }
if (Test-Path -LiteralPath $docx) { Remove-Item -LiteralPath $docx -Force }

function Esc([string]$s) {
  if ($null -eq $s) { return "" }
  $s = $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
  return $s
}
function Para([string]$text, [string]$style) {
  $t = Esc $text
  $pr = if ($style) { "<w:pPr><w:pStyle w:val=`"$style`"/></w:pPr>" } else { "" }
  return "<w:p>$pr<w:r><w:t xml:space=`"preserve`">$t</w:t></w:r></w:p>"
}

$body = New-Object Text.StringBuilder
foreach ($ln in [IO.File]::ReadAllLines($src, [Text.Encoding]::UTF8)) {
  $t = $ln.TrimEnd()
  if     ($t -match '^#\s+(.*)$')       { [void]$body.Append((Para $Matches[1] "Heading1")) }
  elseif ($t -match '^##\s+(.*)$')      { [void]$body.Append((Para $Matches[1] "Heading2")) }
  elseif ($t -match '^###\s+(.*)$')     { [void]$body.Append((Para $Matches[1] "Heading3")) }
  elseif ($t -match '^\s*[-*]\s+(.*)$') { [void]$body.Append((Para ("- " + $Matches[1]) "")) }
  elseif ($t -eq "")                    { [void]$body.Append("<w:p/>") }
  else                                  { [void]$body.Append((Para $t "")) }
}

$docXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
$($body.ToString())
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr>
</w:body>
</w:document>
"@

$stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="26"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:i/><w:sz w:val="23"/></w:rPr></w:style>
</w:styles>
"@

$contentTypes = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>
"@

$rels = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"@

$docRels = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@

$zip = [IO.Compression.ZipFile]::Open($docx, 'Create')
function AddEntry($zip, $name, $content) {
  $e = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
  $s = $e.Open()
  $bytes = [Text.Encoding]::UTF8.GetBytes($content)
  $s.Write($bytes, 0, $bytes.Length)
  $s.Close()
}
AddEntry $zip "[Content_Types].xml" $contentTypes
AddEntry $zip "_rels/.rels" $rels
AddEntry $zip "word/document.xml" $docXml
AddEntry $zip "word/styles.xml" $stylesXml
AddEntry $zip "word/_rels/document.xml.rels" $docRels
$zip.Dispose()
Write-Host ("  OK  {0}.docx  ({1} KB)" -f $Name, [math]::Round((Get-Item -LiteralPath $docx).Length/1KB,1))