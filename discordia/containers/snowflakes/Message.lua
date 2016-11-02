local Snowflake = require('../Snowflake')
local Container = require('../../utils/Container')

local insert = table.insert
local format = string.format
local wrap, yield = coroutine.wrap, coroutine.yield

local Message, get, set = class('Message', Snowflake)

function Message:__init(data, parent)
	Snowflake.__init(self, data, parent)
	local channel = self._parent
	local client = channel._parent._parent or channel._parent
	self._author = client._users:get(data.author.id) or client._users:new(data.author)
	self:_update(data)
end

get('channel', '_parent', 'TextChannel')
get('author', '_author', 'User')

get('member', function(self)
	local channel = self._parent
	if channel._is_private then return end
	return self._author:getMembership(channel._parent)
end, 'Member')

get('guild', function(self) -- guild does not exist for messages in private channels
	return self._parent._parent
end, 'Guild')

get('tts', '_tts', 'boolean')
get('type', '_type', 'string')
get('pinned', '_pinned', 'boolean')
get('content', '_content', 'string')
get('timestamp', '_timestamp', 'string')
get('editedTimestamp', '_edited_timestamp', 'string')

function Message:__tostring()
	return format('%s: %s', self.__name, self.content)
end

function Message:_update(data)
	Snowflake._update(self, data)
	if data.mentions then
		local channel = self._parent
		local client = channel._parent._parent or channel._parent
		local users = client._users
		local mentions = {}
		for _, data in ipairs(data.mentions) do
			insert(mentions, users:get(data._id) or users:new(data))
		end
		self._mentions = mentions
	end
	if data.mention_roles ~= nil then self._mention_roles = data.mention_roles end
	-- self.embeds = data.embeds -- TODO
	-- self.attachments = data.attachments -- TODO
end

get('mentionedUsers', function(self)
	local mentions, k, v = self._mentions
	if not mentions then return function() end end
	return function()
		k, v = next(mentions, k)
		return v
	end
end, 'function')

get('mentionedRoles', function(self)
	return wrap(function()
		local guild = self._parent._parent
		if self._mention_everyone then
			yield(guild.defaultRole)
		end
		if self._mention_roles then
			local roles = guild._roles
			for _, id in ipairs(self._mention_roles) do
				local role = roles:get(id)
				if role then yield(role) end
			end
		end
	end)
end, 'function')

get('mentionedChannels', function(self)
	return wrap(function()
		local textChannels = self._parent._parent._textChannels
		for id in self._content:gmatch('<#(.-)>') do
			local channel = textChannels:get(id)
			if channel then yield(channel) end
		end
	end)
end, 'function')

function Message:mentionsUser(user)
	for obj in self:getMentionedUsers() do
		if obj == user then return true end
	end
	return false
end

function Message:mentionsRole(role)
	for obj in self:getMentionedRoles() do
		if obj == role then return true end
	end
	return false
end

function Message:mentionsChannel(channel)
	for obj in self:getMentionedChannels() do
		if obj == channel then return true end
	end
	return false
end

set('content', function(self, content)
	local channel = self._parent
	local client = channel._parent._parent or channel._parent
	local success, data = client._api:editMessage(channel._id, self._id, {content = content})
	if success then self._content = data.content end
	return success
end)

function Message:reply(...)
	return self._parent:sendMessage(...)
end

function Message:pin()
	local channel = self._parent
	local client = channel._parent._parent or channel._parent
	local success, data = client._api:addPinnedChannelMessage(channel._id, self._id)
	if success then self._pinned = true end
	return success
end

function Message:unpin()
	local channel = self._parent
	local client = channel._parent._parent or channel._parent
	local success, data = client._api:deletePinnedChannelMessage(channel._id, self._id)
	if success then self._pinned = false end
	return success
end

function Message:delete()
	local channel = self._parent
	local client = channel._parent._parent or channel._parent
	local success, data = client._api:deleteMessage(channel._id, self._id)
	return success
end

return Message
