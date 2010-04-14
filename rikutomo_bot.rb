#!/usr/bin/env ruby
# coding: utf-8

require 'date'
require 'rubygems'
require 'oauth'
require 'json'
require 'hpricot'
require 'open-uri'
require 'yaml'

### TODO:
###  ・TwitterBaseクラスはあとで外に出す

# Usage:
# ruby lrhert_twitter.rb /path/to/sercret_key.yml /path/to/lrhert.yml

# TwitterのAPIとのやりとりを行うクラス
class TwitterBase
  def initialize
    # config.yml内のsercret_keys.ymlをloadします。
    @secret_keys = YAML.load_file(ARGV[0] || 'sercret_key.yml')
  end
  
  def consumer_key
    @secret_keys["ConsumerKey"]
  end

  def consumer_secret
    @secret_keys["ConsumerSecret"]
  end

  def access_token_key
    @secret_keys["AccessToken"]
  end

  def access_token_secret
    @secret_keys["AccessTokenSecret"]
  end

  def consumer
    @consumer = OAuth::Consumer.new(
      consumer_key,
      consumer_secret,
      :site => 'http://twitter.com'
    )
  end

  def access_token
    consumer
    access_token = OAuth::AccessToken.new(
      @consumer,
      access_token_key,
      access_token_secret
    )
  end

  def post(tweet=nil)
    response = access_token.post(
      'http://twitter.com/statuses/update.json',
      'status'=> tweet
    )
  end
end
      
class Rikutomo
  attr_reader :post_contents

  def initialize
    @contents      = []
    @post_contents = []
  end

  def base_url
    "http://rikutomo.jp"
  end

  # リクトモの新着・更新日記を取得
  def feed
    Hpricot(open("#{base_url}/pc/users/diary/search_new_diaries"))
  end

  # タイトルとリンクを取得のためのパース
  def diary_list(doc = feed)
    doc.search("//div[@id='article_title_in_list']")
  end

  # 時間を取得のためのパース
  def diary_time_list(doc = feed)
    doc.search("//div[@id='article_information_in_list']")
  end

  def make_post_contents

    # タイトルとリンクを取得
    diary_list.each_with_index do |diary, index|
      doc = Hpricot(diary.inner_html)
  
      # http://ruby.g.hatena.ne.jp/garyo/20061207/1165477582
      hrefs  = (doc/:a).map {|elem| elem[:href]}

      # title,link
      hrefs.each do |link|
        @contents[index] = ["#{(doc/'a').inner_html}","#{base_url}#{link}"]
      end
    end

    # 日記の時間を取得
    diary_time_list.each_with_index do |time, index|
      doc = Hpricot(time.inner_html)
      # 09月08日02:57 => 9080257
      # title,link,更新時間
      @contents[index] << "#{(doc).inner_html.gsub(/ |月|日|:/, '')}"
    end
  end

  def filter
    @contents.each_with_index do |content, index|
      if content[2].gsub(/\n/,'').to_i > (Time.now - interval).strftime("%m%d%H%M").to_i
        @post_contents << content
      end
    end
 
  end

  private

  # 更新日時が今から１時間以内なら、Twitterにポスト
  def interval
    3600
  end
end

twitter_base = TwitterBase.new
rikutomo     = Rikutomo.new
rikutomo.make_post_contents
rikutomo.filter

rikutomo.post_contents.each do |post_content|
  twitter_base.post("#{post_content[0]} #{post_content[1]} (#{post_content[2].gsub(/\n/,'').to_i})")
end
