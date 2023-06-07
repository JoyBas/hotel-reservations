# hotel-reservations
## Code first girls final project

This project uses a subset of the hotel reservations dataset from Kaggle.
Link to original dataset: [Kaggle](https://www.kaggle.com/datasets/ahsan81/hotel-reservations-classification-dataset)

## The approach to this project
1 Identify my area of interest: Understanding hotel reservations
2 Questions I would want to answer with the data such as
  - identify reservation patterns and the number of guests in different months
  - compare reservations verse cancellations
  - spot unusual things such as 'Did children check into the hotel without adults'
  - calculate the average prices earned in different months
3 Sourced the data from Kaggle 
  - Using the star schema, created the database which consists of 4 dimension tables and one fact table
  - The dimensions are related to the fact table with the use of foreign keys
  - The data year spans two years (2017 - 2018)
