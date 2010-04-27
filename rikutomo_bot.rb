#!/usr/bin/env ruby
# coding: utf-8

require 'date'
require 'rubygems'
require 'oauth'
require 'json'
require 'hpricot'
require 'open-uri'
require 'yaml'
require File.dirname(__FILE__) + '/twitter_oauth'

# Usage:
#  1. このファイルと同じディレクトリに以下2つのファイルを設置します。
#   * twitter_oauth.rb
#   * http://github.com/japanrock/TwitterTools/blob/master/twitter_oauth.rb
#   * sercret_key.yml
#   * http://github.com/japanrock/TwitterTools/blob/master/secret_keys.yml.example
#  2. このファイルを実行します。
#   ruby rikutomo_bot.rb
     
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
        # HTMLタグを取り除く
        title = (doc/'a').inner_html.gsub(/<\/?[^>]*>/, '[絵]')

        @contents[index] = ["#{title}","#{base_url}#{link}"]
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

twitter_oauth = TwitterOauth.new
rikutomo      = Rikutomo.new
rikutomo.make_post_contents
rikutomo.filter

rikutomo.post_contents.each do |post_content|
  twitter_oauth.post("#{post_content[0]} #{post_content[1]} (#{post_content[2].gsub(/\n/,'').to_i})")
end
