local bit = require("bit")

local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local lshift, rshift, rol = bit.lshift, bit.rshift, bit.rol
local tohex = bit.tohex
local floor = math.floor

MSP_STATUS = 101
MSP_SET_RAW_RC = 200
MSP_UID = 160
MSP_ALTITUDE   = 109
MSP_IDENT      = 100
MSP_BAT        = 110

local roll, pitch, yaw, gaz = 0, 0, 0, 0
local aux1, aux2, aux3 = 0, 0, 0
local data = {}

local font = nil
local fontY = 0

function love.load(arg)

	update_timer = 0

	love.joystick.loadGamepadMappings("gamecontrollerdb.map")
	love.graphics.setNewFont(50)
	font = love.graphics.getFont()
	fontY = font:getHeight()

	gatt = io.popen("gatttool -t random -b "..adresse.." -I > /dev/null", "w") -- run gatttool
	gatt:write("connect\n"); -- connect to ble peripheral

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
	serial = Serial("/dev/ttyACM0", 115200)
	roll, pitch, yaw, gaz = 0, 0, 0, 0
	update_timer = 0
	msg_disp = ""
	love.graphics.setFont(love.graphics.newFont(32))
end

function msp_send(serial, type, size, data)
	if data == nil then data = "" end
	checksum = bit.bxor(type, size)
	for i = 1, #data do
		local c = data:sub(i, i)
		checksum = bit.bxor(checksum, c:byte())
	end
	local msg = "$M<" .. struct.pack("bb",size, type) .. data .. struct.pack("b", checksum)

	-- local msg = "$M<" .. struct.pack("bbb", 0, 232, 232) --.. "\n"
	serial:write(msg)
	local out = ""
	for i = 1, #msg do
		local c = msg:sub(i,i)
		out = out..string.format("%X ", c:byte())
	end
	print(out)
end


function love.update(dt)

	update_timer = update_timer + dt

	if update_timer > 0.025 then -- ( 40Hz = 0.025)

		update_timer = 0

		if joy then
			gaz   = 511 * joy:getGamepadAxis( "lefty" ) + 512
			yaw   = 511 * joy:getGamepadAxis( "leftx" ) + 512
			roll  = 511 * joy:getGamepadAxis( "rightx" ) + 512
			pitch = 511 * joy:getGamepadAxis( "righty" ) + 512
		else
			gaz, yaw, roll, pitch = 42, 42, 42, 42
		end

		for i=1,6 do data[i-1] = 0 end            -- memset(data, 0, sizeof(data))

		data[0] = bor(data[0], rshift(gaz, 2))    -- data[0] |= gaz >> 2;
		data[1] = bor(data[1], lshift(gaz, 6))    -- data[1] |= gaz << 6;

		--print(aux1)

		data[2] = bor(data[2], rshift(roll, 6));  -- data[2] |= roll >> 6;
		data[3] = bor(data[3], lshift(roll, 2));  -- data[3] |= roll << 2;

		msp_send(serial, MSP_SET_RAW_RC, 8, struct.pack("hhhhhhhh",1,2,3,4,5,6,7,8))
		update_timer = 0


		--msp_send(serial, MSP_UID, 0)

		--serial:write(struct.pack("hhhhhhh", gaz, roll, pitch, yaw, aux1, aux2, aux3).."\n")

		data, buffer = readInput(serial)
		if data then
			local msg = ""
			for i = 1, #buffer do
				local c = buffer:sub(i,i)
				msg = msg..string.format("%X",c:byte())
			end
			print(msg)
			msg_disp = msg
		end
	end

end


function love.draw()
	love.graphics.print("gaz: "..floor(gaz),     10, fontY * 0)
	love.graphics.print("yaw: "..floor(yaw),     10, fontY * 1)
	love.graphics.print("roll: "..floor(roll) ,  10, fontY * 2)
	love.graphics.print("pitch: "..floor(pitch), 10, fontY * 3)

	love.graphics.print("aux1: "..floor(aux1), 10, fontY * 4)
	love.graphics.print("aux2: "..floor(aux2), 10, fontY * 5)
	love.graphics.print("aux3: "..floor(aux3), 10, fontY * 6)
end


function love.keypressed(key, scancode, isrepeat)
	print(key)
	if key == "escape" then love.event.quit() end
end


function love.gamepadpressed( joystick, button )
	print("button",button)
	if button == "a" then
		aux1 = (aux1 + 1) % 4
	end
	if button == "b" then
		aux2 = (aux2 + 1) % 4
	end
	if button == "x" then
		aux3 = (aux3 + 1) % 4
	end
end


function love.joystickadded(joystick)
	joy = joystick
end


function love.quit()
	--serial:close()
	print("quit")
	gatt:write("quit\n")
	gatt:flush()
	os.execute("killall gatttool")
end
