module vproto

pub enum ProtoSyntax {
	proto2
	proto3
}

pub struct File {
mut:
	filename string 
	path string

	syntax ProtoSyntax // syntax of the file

	package string
	imports []Import
	options []OptionField
	enums []Enum
	messages []Message
	extends []Extend
	services []Service
}