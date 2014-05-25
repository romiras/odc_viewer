#!/usr/bin/env ruby
# encoding: UTF-8
require 'rubygems' # for ruby 1.8
require 'uri'
require 'httparty'
require 'tmpdir'
require 'sinatra'


ERR_CONN = -1
ERR_NOT_ODC_FORMAT = -2
ERR_DOCU_SIZE_EXCEED = -3

LIMIT = 4 * 1024 * 1024  # in bytes. A maximum size of downloading file.

# download("http://...", "/tmp/temp.odc")
def download(url, local_path)
	status = 200
	success = false
	begin
		response = HTTParty.get(URI.escape(url))   # fetches document's content into memory. TODO care large files by handing HTTP headers properly.
		
		case response.code
			when 200
				if response['content-length'].to_i < LIMIT
					open(local_path, "wb") { |file| file.write(response.body) }
					success = true
				end
			when 404
				status = 404
			when 504
				status = 504
			when 500
				status = 500
			else
				$stderr.puts response
				status = response.code
		end
	rescue Timeout::Error, Errno::ETIMEDOUT, #Errno::EINVAL, EOFError,
		Errno::ECONNRESET, Errno::ECONNREFUSED => e
		$stderr.puts(e.inspect)
		case e
			when Timeout::Error, Errno::ETIMEDOUT
				status = 504
			when Errno::ECONNRESET, Errno::ECONNREFUSED
				status = ERR_CONN
			else
				status = 500
	   end
   end
   
   return [success, status]
end

def process_url(odc_url)
	tmp_dir = Dir.tmpdir
	template_name = rand(1 << 31).to_s(16)

	name_in = "tmp#{template_name}.odc"  # name of temporary file of downlowing file
	temp_odc_path = File.join(tmp_dir, name_in)
	
	success, status = download(odc_url, temp_odc_path)
	if success
		# Convert into text and read  output from pipe
		cmd = "/usr/local/bin/odcread \"#{temp_odc_path}\""
		begin
		pipe = IO.popen(cmd)
		content = pipe.read
		rescue StandardError => e
		  $stderr.puts e.inspect
		  content = e.inspect
		  status = -9
		end
		File.delete(temp_odc_path) #if content != ''
	elsif status == 200
		status = ERR_DOCU_SIZE_EXCEED  # HTTP 413
		content = ''
	else
		content = ''
	end
	
	return status, content
end

get '/odcviewer' do
	odc_url = params[:odc]

	# 1. target URL contains ".odc" as extension. If not, return "Oberon/F document type expected."
	# 2. try download. If failed (404) - return 404; See other 40x errors as well.
	# 3. try convert by odcread. If failed, return 500
	
	if odc_url =~ URI::regexp && odc_url =~ /\.odc(\?.*)?$/
		status, content = process_url(odc_url)
	else
		status, content = ERR_NOT_ODC_FORMAT, ''
	end
	
	content = "Error: failed convert ODC at this URL: %s" % odc_url if status == 200 && content == ''

	# send content to HTTP client
	case status
		when 200
			return "<pre>#{content}</pre>"
		when 504
			return "Cannot retrieve a requested document (reponse from remote server): %s." % 'Timeout'
		when ERR_CONN
			return "Cannot retrieve a requested document: %s" % "Connection error"
		when ERR_NOT_ODC_FORMAT
			return "Oberon/F document type expected."
		when ERR_DOCU_SIZE_EXCEED
			return "Request Entity Too Large. Sorry."
			# head 413
		when -9
			return "Cannot retrieve a requested document: %s." % "Error #{content}"
		else
			return "Cannot retrieve a requested document (reponse from remote server): %s." % "Error #{status.inspect}"
	end
end
