# redline.rb - Simple artist feedback and critique
#
# Copyright (C) 2015 Ryan Mendivil <ryan@nullreff.net>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of Redline nor the names of its contributors may be
#     used to endorse or promote products derived from this software without
#     specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'active_support'
require 'active_support/core_ext'
require 'json'
require 'open-uri'
require 's3'
require 'securerandom'
require 'sinatra/base'
require 'sinatra/json'
require 'yaml'

UUID_REGEX = '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}'

module Redline
  class << self
    attr_accessor :config
  end

  class Application < Sinatra::Base
    set :public_folder, File.join(File.dirname(__FILE__), 'public')
    set :views, File.join(File.dirname(__FILE__), 'views')

    def initialize(app, config = {})
      Redline.config = config.with_indifferent_access
      raise "S3 acesss keys not configured" unless Redline.config[:s3]
      @s3 = S3::Service.new(access_key_id: Redline.config[:s3][:access_key_id],
                            secret_access_key: Redline.config[:s3][:secret_access_key])
      super(app)
    end

    helpers do
      def bad_request(message)
        halt 400, message
      end

      def service_unavailable(message)
        halt 503, message
      end

      def s3_unavailable
        service_unavailable('We\'re having trouble with our file storage. Try again later')
      end

      def s3_image_url(key)
        "http://#{Redline.config[:s3][:bucket]}.s3.amazonaws.com/images/#{key}"
      end

      def s3_redline_url(key)
        "http://#{Redline.config[:s3][:bucket]}.s3.amazonaws.com/redlines/#{key}/"
      end

      def add_google_analytics(key)
        if settings.production?
          %Q{
            <script>
              (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
              (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
              m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
              })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

              ga('create', '#{key}', 'auto');
              ga('send', 'pageview');
            </script>
          }
        end
      end
    end

    get '/' do
      haml :index, layout: :page
    end

    get '/about' do
      haml :page do
        markdown :about
      end
    end

    get %r{/(#{UUID_REGEX})/new} do |key|
      @image = s3_image_url(key)
      haml :new, layout: :page
    end

    post %r{/(#{UUID_REGEX})/new} do |key|
      # We're reparsing and reconstructing the data to ensure that
      # we don't inject something nasty into our output page
      output = begin
        data = JSON.parse(request.env["rack.input"].read)
        {feedback: data['feedback'], image: data['image']}.to_json
      rescue
        bad_request('Invalid JSON provided')
      end

      redline_key = SecureRandom.uuid
      bucket = @s3.buckets.find(Redline.config[:s3][:bucket])
      index_data =
        begin
          open(s3_redline_url(key) + 'index', &:read)
        rescue
          nil
        end
      index_file = if index_data
        file = bucket.objects.find("redlines/#{key}/index")
        file.content = "#{index_data}\n#{redline_key}".strip
        file
      else
        file = bucket.objects.build("redlines/#{key}/index")
        file.content = redline_key
        file
      end

      redline_file = bucket.objects.build("redlines/#{key}/#{redline_key}")
      redline_file.content = output

      redline_file.save
      index_file.save

      'Success'
    end

    get %r{/(#{UUID_REGEX})/view} do |key|
      @link = "#{request.base_url}/#{key}/new"
      @base_url = s3_redline_url(key)
      @artwork_url = s3_image_url(key)
      haml :view, layout: :page
    end

    post '/upload' do
      if !params[:image] || !params[:image][:filename] || !params[:image][:tempfile]
        bad_request('You must provide a file in the "image" parameter')
      end

      extension = File.extname(params[:image][:filename])
      if extension !~ /^\.[a-zA-Z0-9]+$/
        bad_request('The file you uploaded is not in a recognized image format')
      end

      key = SecureRandom.uuid
      file = params[:image][:tempfile]

      bucket = @s3.buckets.find(Redline.config[:s3][:bucket])
      object = bucket.objects.build("images/#{key}")
      object.content = open(file)
      s3_unavailable unless object.save

      redirect to("/#{key}/view")
    end

    error do
      status 500
      'Redline encounter an internal error'
    end
  end
end
