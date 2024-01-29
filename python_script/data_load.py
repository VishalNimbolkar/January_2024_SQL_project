import pandas as pd 
from sqlalchemy import create_engine

conn_string = 'postgresql://postgres:Password@localhost:5432/painting'
engine = create_engine(conn_string)
conn = engine.connect()


data_files = ['artist', 'canvas_size', 'image_link', 'museum_hours', 'museum', 'product_size', 'subject', 'work']

for file in data_files:
    df = pd.read_csv(f'C:/Users/visha/Personal/Techtfq/Famous_Painting_Dataset/{file}.csv')
    df.to_sql(file, con=conn, if_exists='replace', index=False)
