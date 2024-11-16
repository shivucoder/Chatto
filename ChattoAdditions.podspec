Pod::Spec.new do |s|
  s.name         = "ChattoAdditions"
  s.version      = "4.1.0"
  s.summary      = "UI componentes for Chatto"
  s.description  = <<-DESC
                   Text and photo bubbles
                   Input bar for text and photo messages
                   DESC
  s.homepage     = "https://github.com/badoo/Chatto"
  s.license      = { :type => "MIT"}
  s.platform     = :ios, "11.1"
  s.authors      = { 'Diego Sanchez' => 'diego.sanchezr@gmail.com', 'Anton Schukin' => 'a.p.schukin@gmail.com' }
  s.source       = { :git => "https://github.com/badoo/Chatto.git", :tag => s.version.to_s }
  s.source_files = "ChattoAdditions/sources/**/*.{h,m,swift}"
  s.public_header_files = "ChattoAdditions/sources/**/*.h"
  s.requires_arc = true
  s.swift_version = '5.3'
  s.resource_bundle = { 'ChattoAdditionsResources' => ["ChattoAdditions/sources/**/*.xib", "ChattoAdditions/sources/**/*.storyboard", "ChattoAdditions/sources/**/*.xcassets"] }
  s.dependency 'Chatto', s.version.to_s
end
