#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_term(term, url)
  noko = noko_for(url)
  noko.css('li.parl-i').each do |li|
    etrap = li.css('.parl-i--d').text.tidy

    if etrap.downcase.include? 'okrug'
      area, area_id = li.css('.parl-i--d').text.match(/Saýlaw etrap №(\d+)-nj[iy] "(.*?)" saýlaw okrugy/).captures
    else
      area_id = li.css('.parl-i--d').text[/Saýlaw etrap №(\d+)/, 1]
      area = etrap
    end

    person = { 
      id: li.css('a/@href').text.split('/').last,
      name: li.css('a').text.tidy,
      area: area,
      area_id: area_id,
      image: li.css('img/@src').text,
      term: term[:id],
      source: li.css('a/@href').text,
    }
    person[:image] = URI.join(term[:source], person[:image]).to_s unless person[:image].to_s.empty?
    person[:source] = URI.join(term[:source], person[:source]).to_s unless person[:source].to_s.empty?
    data = person.merge(scrape_person(person))
    ScraperWiki.save_sqlite([:id, :term], data)
  end

  unless (next_page = noko.css('.p-l .p-i--next a/@href')).empty?
    scrape_term(term, URI.join(url, next_page.text))
  end
end

def scrape_person(person)
  noko = noko_for(person[:source])
  data = { 
    district: noko.css('.bio-i--rg .bio-i--cnt').text,
    party: noko.css('.bio-i--lbl .bio-i--cnt').text,
    birth_year: noko.css('.bio-i--by .bio-i--cnt').text,
  }
end

terms = [
  {
    id: 5,
    name: '5th Convocation',
    start_date: '2013',
    source: 'http://mejlis2.bushluk.com/tm/parliamentaries/search/?convocation=14118',
  },
  {
    id: 4,
    name: '4th Convocation',
    start_date: '2009',
    end_date: '2013',
    source: 'http://mejlis2.bushluk.com/tm/parliamentaries/search/?convocation=2159',
  },
]

terms.each do |term|
  puts term
  # ScraperWiki.save_sqlite([:id], term, 'terms')
  scrape_term(term, term[:source])
end


