Pod::Spec.new do |s|

  s.name         = "DSRedis"
  s.version      = "0.0.1"
  s.summary      = "Redis"

  s.description  = <<-DESC
  					Redis
                   DESC

  s.homepage     = "http://github.com/dictav/Redis"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author             = { "dictav" => "dictav@gmail.com" }
  s.social_media_url = "http://twitter.com/dictav"

  s.source       = { :git => "https://github.com/dictav/Redis.git", :tag => "0.0.1", :submodules => true }
  s.source_files  = ['DSRedis/DSRedis.{h,m}', 'hiredis/fmacros.h', 'hiredis/hiredis.{h,c}', 'hiredis/dict.{h,c}', 'hiredis/net.{h,c}', 'hiredis/sds.{h,c}']

  s.requires_arc  = true
end
