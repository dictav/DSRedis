Pod::Spec.new do |s|

  s.name         = "DSRedis"
  s.version      = "0.0.7"
  s.summary      = "Redis"

  s.description  = <<-DESC
  					DSRedis is hiredis wrapper for Objective-C
                   DESC

  s.homepage     = "http://github.com/dictav/DSRedis"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author             = { "dictav" => "dictav@gmail.com" }
  s.social_media_url = "http://twitter.com/dictav"

  s.source       = { :git => "https://github.com/dictav/DSRedis.git", :tag => s.version, :submodules => true }
  s.source_files  = ['DSRedis/DSRedis.{h,m}', 'hiredis/fmacros.h', 'hiredis/hiredis.{h,c}', 'hiredis/dict.{h,c}', 'hiredis/net.{h,c}', 'hiredis/sds.{h,c}']

  s.requires_arc  = true
end
