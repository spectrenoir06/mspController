local Serial = require('periphery').Serial
local struct = require("struct")
local bit = require("bit")

local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local lshift, rshift, rol = bit.lshift, bit.rshift, bit.rol

MSP_SET_RAW_RC = 200
MSP_SERIAL_UUID = 232
MSP_ALTITUDE   = 109
MSP_IDENT      = 100
MSP_BAT        = 110


function sleep(n)
	os.execute("sleep "..tonumber(n))
end

local ffi = require'ffi'
local bit = require'bit'

local s_crc32 = ffi.new('const uint32_t[16]',
	0x00000000, 0x1db71064, 0x3b6e20c8, 0x26d930ac,
	0x76dc4190, 0x6b6b51f4, 0x4db26158, 0x5005713c,
   0xedb88320, 0xf00f9344, 0xd6d6a3e8, 0xcb61b38c,
	0x9b64c2b0, 0x86d3d2d4, 0xa00ae278, 0xbdbdf21c)

local function crc32(buf, sz, crc)
	crc = crc or 0
	sz = sz or #buf
	buf = ffi.cast('const uint8_t*', buf)
	crc = bit.bnot(crc)
	for i = 0, sz-1 do
		crc = bit.bxor(bit.rshift(crc, 4), s_crc32[bit.bxor(bit.band(crc, 0xF), bit.band(buf[i], 0xF))])
		crc = bit.bxor(bit.rshift(crc, 4), s_crc32[bit.bxor(bit.band(crc, 0xF), bit.rshift(buf[i], 4))])
	end
	return bit.bnot(crc)
end


roll, pitch, yaw, gaz = 0, 0, 0, 0

--------------------------------------------------------------------------------

function writeCmdCallback(serial, cmd, wait, callback)
	io.write("\n#"..cmd)
	serial:write(cmd)
	if wait and wait > 0 then
		sleep(wait)
	end
	local input = ""
	while not input:find(">") do
		local data, buff = readInput(serial)
		if buff then
			input = input..buff
		end
	end
	if type(callback) == "function" then
		callback(data, buff or "")
	end
	io.write(":"..input)
end

function readInput(serial)
	local bytes = serial:input_waiting()
	-- print(bytes)
	if bytes > 0 then
		local buff = serial:read(bytes)
		return true, buff
	end
	return false
end

function printInput(serial)
	local data, buff = readInput(serial)
	if data then
		io.write(buff)
		return true
	end
	return false
end

function love.load(arg)
	serial = Serial("/dev/ttyACM1", 115200)
	roll, pitch, yaw, gaz = 0, 0, 0, 0
	update_timer = 0
	msg_disp = ""
	love.graphics.setFont(love.graphics.newFont(32))
end

function msp_send(serial, type, size, data)
	if data == nil then data = "" end
	-- checksum = bit.bxor(type,size)
	-- for i = 1, #data do
	-- 	local c = data:sub(i,i)
	-- 	checksum = bit.bxor(checksum,c)
	-- end
	-- local msg = "$M<" .. struct.pack("bb",type, size) .. data .. struct.pack("b", checksum) --.. "\n"

	local msg = "$M<" .. struct.pack("bbb", 0, 232, 232) .. "\n"
	serial:write(msg)
end

local counter = 0

function love.update(dt)
	-- print(dt,1/dt)

	if love.keyboard.isDown("up") then
		pitch = 50
	elseif love.keyboard.isDown("down") then
		pitch = -50
	else
		pitch = 0
	end

	if love.keyboard.isDown("left") then
		roll = 50
	elseif love.keyboard.isDown("right") then
		roll = -50
	else
		roll = 0
	end


	update_timer = update_timer + dt
	if update_timer > 0.02 then
		-- msp_send(serial, MSP_SET_RAW_RC, 8, struct.pack("hhhhhhhh",1,2,3,4,5,6,7,8))
		update_timer = 0
		serial:write(struct.pack("B",counter).."\n")
		counter = counter + 1
		--msp_send(serial, MSP_SERIAL_UUID, 0, "")
		data, buffer = readInput(serial)
		if data then
			--local msg = ""
			--for i = 6, #buffer -1 do
			--	local c = buffer:sub(i,i)
			--	msg = msg..string.format("%x ",c:byte())
			--end
			print(buffer)
			--msg_disp = msg
		end
	end
end

function love.draw()
	love.graphics.print("serial: "..msg_disp, 10, 10)
end

function love.keypressed(key, scancode, isrepeat)

	if key == "space" then
		love.system.setClipboardText(msg_disp)
	end
end


function love.quit()
	serial:close()
end
