*** Settings ***
Documentation    Verify miscellaneous aspects of category creation
Library          Selenium2Library
Suite Setup      Before Test Suite
Suite Teardown   After Test Suite
Force Tags       category  misc

*** Test Cases ***
Category name should be stripped from leading and trailing spaces
	[Documentation]            Verify removing of leading and trailing spaces from name
	Input Text                 id=name  ${SPACE * 2}t3st${SPACE * 2}
	Input Text                 id=nameRu  ${SPACE * 2}т3ст${SPACE * 2}
	Submit Form                id=add-category-form
	Textfield Value Should Be  id=name  t3st
	Textfield Value Should Be  id=nameRu  т3ст

Category name should be modified by replacing multiple spaces by one
	[Documentation]            Verify replacing of repeating spaces from name
	Input Text                 id=name  t3${SPACE * 2}st
	Input Text                 id=nameRu  т3${SPACE * 2}ст
	Submit Form                id=add-category-form
	Textfield Value Should Be  id=name  t3 st
	Textfield Value Should Be  id=nameRu  т3 ст

Category name in English should accept all allowed characters
	[Documentation]                  Verify that various characters in name are allowed
	Input Text                       id=name  Valid-Name Category
	# we also type invalid name in Russian to stay on this page
	Input Text                       id=nameRu  1
	Submit Form                      id=add-category-form
	Page Should Not Contain Element  id=name.errors

Category name in Russian should accept all allowed characters
	[Documentation]                  Verify that various characters in name are allowed
	Input Text                       id=nameRu  Категория Ёё
	# we also type invalid name in English to stay on this page
	Input Text                       id=name  1
	Submit Form                      id=add-category-form
	Page Should Not Contain Element  id=nameRu.errors

*** Keywords ***
Before Test Suite
	[Documentation]                     Login as admin and go to create category page
	Open Browser                        ${SITE_URL}  ${BROWSER}
	Register Keyword To Run On Failure  Log Source
	Log In As                           login=admin  password=test
	Go To                               ${SITE_URL}/category/add

After Test Suite
	[Documentation]  Log out and close browser
	Log Out
	Close Browser

Log In As
	[Documentation]  Log in as a user
	[Arguments]      ${login}  ${password}
	Go To            ${SITE_URL}/account/auth
	Input Text       id=login  ${login}
	Input Password   id=password  ${password}
	Submit Form      id=auth-account-form

Log Out
	[Documentation]  Log out current user
	Submit Form      id=logout-form
