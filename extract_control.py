#!/usr/bin/env python

import re

class setup_file(object):
    def __init__(self, filename='setup.ini'):
        self.filename = filename
        self.file = open(filename, 'rb')
        self.contents = self.file.read()
        self.contents = self.sanitize_contents(self.contents)

    def sanitize_contents(self, contents):
        contents = '\n\n' + contents
        contents = contents.replace('\r','')
        contents = re.sub("\n[ \t]*[#].*(?=\n)", "", contents)
        contents = re.sub("\n[ \t]+\n", "\n\n", contents)
        contents = re.sub("\n\n[\n]+", "\n\n", contents)
        contents = contents.strip() + '\n\n'
        
        contents = contents.split('\n')
        contents = '\n'.join([x.strip() for x in contents])
        
        return contents

    def test(self):
        print "Total @ symbols:", self.contents.count('@')
        print "Fresh @ symbols:", len(re.findall("\n[ \t\n]*[@]", self.contents))

    def split_listings(self, contents):
        regex='\n[@].+?(?=\n[@])'
        listings = re.findall(regex,self.contents,flags=re.DOTALL)
        listings = [x.strip() for x in listings]

        return listings

    def sanitize_listing(self, listing):
        name_string = re.findall('\A@.+?\n',listing)[0]
        replacement = name_string + '[current]\n'
        listing = re.sub("\A@.+?\n",replacement,listing)

        match = re.search('\n[a-zA-Z]+?[:][ \t]*["].*?["]', listing, flags=re.DOTALL)
        
        while match != None:
            string = listing[match.start():match.end()]
            string = string.replace('"','')
            string = string.strip()
            string = '\n' + string.replace('\n', ' ')
            listing = listing[0:match.start()] + string + listing[match.end():]
            match = re.search('\n[a-zA-Z]+?[:][ \t]*["].*?["]', listing, flags=re.DOTALL)

        listing = re.sub('[ \t]+',' ', listing)
        return listing

    def read_listing(self, listing):
        result = {}
        
        name = re.findall('\A@.+?\n',listing)[0]
        name = name.strip()
        if name[0] == '@':
            name = name[1:]
        result['name'] = name.strip()

        fields = ['sdesc', 'ldesc', 'category', 'requires']
        fields += ['version', 'install', 'source']

        for field in fields:
            listing = re.sub('\n%s[ \t][:][ \t]*' % field, '\n%s[:] ', listing)
            regex = '(?<=\n%s[:] ).+\n' % field
            value = re.findall(regex, listing)[0].strip()
            result[field] = value

        return result


def main():
    myfile = setup_file()
    myfile.test()
    listings = myfile.split_listings(myfile.contents)
    listings = listings[0:1]
    
    listings = [myfile.sanitize_listing(x) for x in listings]
    for x in listings:
        print x
        print "----------------"
        print myfile.read_listing(x)

if __name__ == '__main__':
    main()
