local assert = assert
local type = assert(type)
local pairs = assert(pairs)
local ipairs = assert(ipairs)
local tonumber = assert(tonumber)
local gsub = assert(string.gsub)
local char = assert(string.char)
local split = assert(string.split)
local random = assert(math.random)
local floor = assert(math.floor)

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function round(num, idp)
	local mult = 10 ^ (idp or 0)
  	return floor(num * mult + 0.5) / mult
end

local function Base64Encode(data)
    	return ((data:gsub('.', function(x) 
        	local r, b = '', x:byte()
        	for i = 8, 1, -1 do  r = r .. ( b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')  end
        	return r
    	end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        	if (#x < 6) then  return '' end
        	local c = 0
        	for i = 1, 6 do  c = c + (x:sub(i,i) == '1' and 2 ^ (6 - i) or 0)  end
        	return b:sub(c + 1, c + 1)
    	end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function Base64Decode(data)
    	data = gsub(data, '[^'..b..'=]', '')
    	return (data:gsub('.', function(x)
        	if (x == '=') then  return '' end
        	local r, f = '',(b:find(x) - 1)
        	for i = 6, 1, -1 do  r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
        	return r
    	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        	if (#x ~= 8) then return '' end
        	local c = 0
        	for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
            	return char(c)
    	end))
end 

class 'AutoUpdate'

function AutoUpdate:__init(LocalVersion, SavePath, Host, VersionPath, ScriptPath, LoadCB, PreUpdateCB, PostUpdateCB, ErrorCB)
	self.SavePath        = SavePath
  	self.Host            = Host
  	self.LoadCB          = LoadCB
  	self.PreUpdateCB     = PreUpdateCB
  	self.PostUpdateCB    = PostUpdateCB
  	self.ErrorCB         = ErrorCB 

  	local FilePath 	     = split(self.SavePath, '/')
  	      FilePath       = split(FilePath[#FilePath], '\\')

  	self.FileName        = FilePath[#FilePath]:gsub('/','')

  	self.LocalVersion    = LocalVersion
	self.VersionPath     = '/GOS/TCPUpdater/GetScript5.php?script=' .. Base64Encode(self.Host .. VersionPath) .. '&rand=' .. random(99999999)
	self.ScriptPath      = '/GOS/TCPUpdater/GetScript5.php?script=' .. Base64Encode(self.Host .. ScriptPath) .. '&rand=' .. random(99999999)
	self.DownloadStatus  = 'Connecting...'
		
    	self:CreateSocket(self.VersionPath)
	Callback.Add("Tick",function( ... ) self:GetOnlineVersion( ... ) end)
end

function AutoUpdate:CreateSocket(url)
  	if not self.LuaSocket then
    		self.LuaSocket = require 'lua\\socket'
  	else
    		self.Socket:close()

    		self.Socket 	  = nil
    		self.Size 	  = nil
    		self.RecvStarted  = false
  	end

  	self.LuaSocket = require 'lua\\socket'
  	self.Socket    = self.LuaSocket.tcp()

  	if not self.Socket then    
    		if self.ErrorCB and type(self.ErrorCB) == 'function' then
      			self.ErrorCB('9001')
      			return
    		end
  	end

  	self.Socket:settimeout(0, 'b')
  	self.Socket:settimeout(99999999, 't')
  	self.Socket:connect('gamingonsteroids.com', 80)

  	self.Url        = url
  	self.Started    = false
  	self.LastPrint  = ""
  	self.File       = ""
end

function AutoUpdate:GetOnlineVersion()
  	if self.GotScriptVersion then return end

  	self.Receive, self.Status, self.Snipped = self.Socket:receive(1024)

  	if self.Status == 'timeout' and not self.Started then
    		self.Started = true
    		self.Socket:send("GET "..self.Url.." HTTP/1.1\r\nHost: gamingonsteroids.com\r\n\r\n")
  	end

  	if (self.Receive or (#self.Snipped > 0)) and not self.RecvStarted then
    		self.RecvStarted     = true
    		self.DownloadStatus  = 'Checking for updates...'
  	end

  	self.File = self.File .. (self.Receive or self.Snipped)

  	if self.File:find('</si'..'ze>') then
    		if not self.Size then
      			self.Size = tonumber(self.File:sub(self.File:find('<si' .. 'ze>') + 6, self.File:find('</si' .. 'ze>') - 1) or '1')
    		end

    		if self.File:find('<scr' .. 'ipt>') then
      			local ScriptFind0, ScriptFind = self.File:find('<scr' .. 'ipt>')
      			local ScriptEnd = self.File:find('</scr' .. 'ipt>')

      			if ScriptEnd then 
      				ScriptEnd = ScriptEnd - 1 
      			end

      			local DownloadedSize = self.File:sub(ScriptFind + 1, ScriptEnd or -1):len()
      			self.DownloadStatus  = 'Checking for updates...'
    		end
  	end

  	if self.File:find('</scr' .. 'ipt>') then
    		self.DownloadStatus = 'Checking for updates...'
    		local a, b     = self.File:find('\r\n\r\n')
    		self.File      = self.File:sub(a, -1)
    		self.NewFile   = ''

    		for line, content in ipairs(self.File:split('\n')) do
      			if content:len() > 5 then
        			self.NewFile = self.NewFile .. content
      			end
    		end

    		local HeaderEnd, ContentStart = self.File:find('<scr' .. 'ipt>')
    		local ContentEnd, ContentEnd0 = self.File:find('</scr' .. 'ipt>')

    		if not ContentStart or not ContentEnd then
      			if self.ErrorCB and type(self.ErrorCB) == 'function' then
        			self.ErrorCB('9002')
      			end
    		else
      			self.OnlineVersion = (Base64Decode(self.File:sub(ContentStart + 1, ContentEnd - 1)))
      			self.OnlineVersion = tonumber(self.OnlineVersion or '0')

			if self.OnlineVersion and self.OnlineVersion > self.LocalVersion then
				if self.PreUpdateCB and type(self.PreUpdateCB) == 'function' then
          				self.PreUpdateCB(self.OnlineVersion, self.LocalVersion)
        			end

        			self.DownloadStatus = 'Connecting...'
        			self:CreateSocket(self.ScriptPath)  

        			Callback.Add("Draw",function( ... ) self:DownloadUpdate( ... ) end)
      			else
        			if self.LoadCB and type(self.LoadCB) == 'function' then
          				self.LoadCB(self.LocalVersion)
        			end
      			end
    		end

    		self.GotScriptVersion = true
  	end
end

function AutoUpdate:DownloadUpdate()
  	if self.GotScriptUpdate then return end

  	self.Receive, self.Status, self.Snipped = self.Socket:receive(1024)

  	if self.Status == 'timeout' and not self.Started then
    		self.Started = true
    		self.Socket:send("GET "..self.Url.." HTTP/1.1\r\nHost: gamingonsteroids.com\r\n\r\n")
  	end

  	if (self.Receive or (#self.Snipped > 0)) and not self.RecvStarted then
    		self.RecvStarted    = true
    		self.DownloadStatus = '(0%)'
  	end

  	self.File = self.File .. (self.Receive or self.Snipped)

  	if self.File:find('</si' .. 'ze>') then
    		if not self.Size then
      			self.Size = tonumber(self.File:sub(self.File:find('<si' .. 'ze>') + 6, self.File:find('</si' .. 'ze>') - 1) or '1')
    		end

    		if self.File:find('<scr'..'ipt>') then
      			local ScriptFind0, ScriptFind = self.File:find('<scr' .. 'ipt>')
      			local ScriptEnd = self.File:find('</scr' .. 'ipt>')

      			if ScriptEnd then 
      				ScriptEnd = ScriptEnd - 1 
      			end

      			local DownloadedSize = self.File:sub(ScriptFind + 1, ScriptEnd or -1):len()
      			self.DownloadStatus = '(' .. round(100 / self.Size * DownloadedSize, 2) .. '%)'
    		end
  	end

  	if self.File:find('</scr' .. 'ipt>') then
    		self.DownloadStatus = '(100%)'
    		local a, b = self.File:find('\r\n\r\n')
                self.File = self.File:sub(a, -1)
    		self.NewFile = ''

    		for line, content in ipairs(self.File:split('\n')) do
      			if content:len() > 6 then
        			self.NewFile = self.NewFile .. content
      			end
    		end

    		local HeaderEnd, ContentStart = self.NewFile:find('<scr' .. 'ipt>')
    		local ContentEnd, ContentEnd0 = self.NewFile:find('</scr' .. 'ipt>')

    		if not ContentStart or not ContentEnd then
      			if self.ErrorCB and type(self.ErrorCB) == 'function' then
        			self.ErrorCB('9003')
      			end
    		else
      			local newf = self.NewFile:sub(ContentStart + 1, ContentEnd - 1)
      			newf = newf:gsub('\r', ''):gsub('\n', '')

      			self.GotScriptUpdate = true

      			if newf:len() ~= self.Size then
        			if self.ErrorCB and type(self.ErrorCB) == 'function' then
          				self.ErrorCB('9004')
        			end
        			return
      			end

      			newf = Base64Decode(newf)

      			if not self.isDownload and type(load(newf)) ~= 'function' then
        			if self.ErrorCB and type(self.ErrorCB) == 'function' then
          				self.ErrorCB('9005')
        			end
      			else
        			local f = io.open(self.SavePath, "w+b")
        			f:write(newf)
        			f:close()

        			if self.PostUpdateCB and type(self.PostUpdateCB) == 'function' then
          				self.PostUpdateCB(self.OnlineVersion,self.LocalVersion)
        			end
      			end
    		end

    		self.GotScriptUpdate = true
  	end
end

function AutoUpdate:DownloadFile()
  	if self.GotScriptUpdate then return end

  	if self.Status == 'closed' then return end

 	self.Receive, self.Status, self.Snipped = self.Socket:receive(1024)

  	if self.Receive then
    		if self.LastPrint ~= self.Receive then
      			self.LastPrint = self.Receive
      			self.File = self.File .. self.Receive
    		end
  	end

  	if self.Snipped ~= "" and self.Snipped then
    		self.File = self.File .. self.Snipped
  	end

  	if self.File:find('Length') then
    		if not self.Size then
      			self.Size = tonumber(self.File:sub(self.File:find('Length') + 8, self.File:find('Length') + 12) or '1') + 602
      			self.DownloadStatus = '(' .. round(100 / self.Size * self.File:len(), 2) / 100 or 0 * 100 .. '%)'
    		end
  	end

  	if self.Status == 'closed' then
    		local HeaderEnd, ContentStart = self.File:find('\r\n\r\n')

    		if HeaderEnd and ContentStart then
      			self.Size = self.File:len()
      			self.DownloadStatus = '(100%)'

      			local f = io.open(self.SavePath, 'w+b')
      			f:write(self.File:sub(ContentStart+1))
      			f:close()

      			self.GotScriptUpdate = true
    		else
      			self.ErrorCB('9006')
    		end
  	end
end
