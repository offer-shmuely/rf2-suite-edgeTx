import json
import os
import re
import requests

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

#def read_messages1():
#    file_path = f'{SCRIPT_DIR}/messages.json'
#    with open(file_path, 'r', encoding='utf-8') as file:
#        return json.load(file)

def read_messages2():
    uri = 'https://raw.githubusercontent.com/rotorflight/rotorflight-configurator/master/locales/en/messages.json'
    response = requests.get(uri)
    json_data = response.json()
    return json_data

def find_unit_in_message(msg):
    parts = re.findall(r"\[(.*?)\]", msg)

    if not parts:
        return None
    return parts[0]

def remove_invalid_chars(msg):
    msg = msg.replace('"', "'")
    msg = msg.replace('&deg;', "deg")
    msg = msg.replace('µs', "us")
    return msg

def generate_lua_code(messages):
    lua_code = "return {"
    for key, value in messages.items():
        if "Help" in key or 'message' not in value:
            continue

        msg = value['message']
        msg = remove_invalid_chars(msg)

        unit = find_unit_in_message(msg)

        hlp = None
        help_keys = [
            f'{key}Help',
            f'{key.removesuffix("Roll")}Help',
            f'{key.removesuffix("Pitch")}Help',
            f'{key.removesuffix("Yaw")}Help',
        ]
        for k in help_keys:
            if k in messages:
                hlp = messages[k]
                break
            pass

        if hlp:
            hl = hlp['message']
            # remove repeating text
            if hl.startswith(f'{msg}. '):
                hl = hl[len(msg)+2:]
                pass


            hl = remove_invalid_chars(hl)
            line = f'{key} = {{ t="{msg}", help="{hl}"'
            if unit:
                unit = remove_invalid_chars(unit)
                line += f', units="{unit}"'
                # print(f'{key}= {unit}')
            line += f' }},'
        else:
            continue

        lua_code += line + '\n'
    lua_code += "}"
    return lua_code

def generate_keys(messages):
    keys= ''
    for key, value in messages.items():
        if "Help" in key or 'message' not in value:
            continue

        hlp = None
        if f'{key}Help' in messages:
            hlp = messages[f'{key}Help']

        msg = value['message']
        msg = msg.replace('"', "'")
        msg = msg.replace('&deg;', "deg")

        unit = find_unit_in_message(msg)

        if hlp:
            hl = hlp['message']
            hl = hl.replace('"', "'")
            line = f'{key}'
        else:
            continue

        keys += line + '\n'

    return keys

def write_to_file(lua_code, file_path):
    with open(file_path, 'w') as file:
        file.write(lua_code)

def main():
    # messages = read_messages1()
    messages = read_messages2()
    lua_code = generate_lua_code(messages)
    # write_lua_code_to_file(lua_code, f'{SCRIPT_DIR}/fields_info.lua')
    # write_to_file(lua_code, f'{SCRIPT_DIR}/../src/SCRIPTS/RF2/touch/fields_info.lua')
    write_to_file(lua_code, f'{SCRIPT_DIR}/../../touch/fields_info.lua')

    keys = generate_keys(messages)
    # write_to_file(keys, f'{SCRIPT_DIR}/../src/SCRIPTS/RF2/touch/keys.txt')
    write_to_file(keys, f'{SCRIPT_DIR}/../../touch/keys.txt')


if __name__ == "__main__":
    main()
