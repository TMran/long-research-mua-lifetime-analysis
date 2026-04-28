import random

# bind = [0, 1, 1, 0]

bind= []
listLength = random.randint(3, 10)

for i in range(listLength):
    x = random.randint(-100, 100)
    bind.append(x)


print("\n")
print("list length = " + str(listLength))
print("bind =", bind)
print("bind[0] =", bind[0])
print("bind[-1] (last element) =", bind[-1])


print("\n--- shows n vs n-1 ---")
for n in range(len(bind)):
    current = bind[n]
    previous = bind[n - 1]


    print(f"n={n}: previous={previous}, current={current}")

print("this works perfectly fine for every instance EXCEPT for the first one where n == 0")

# -----------------

print("\n--- implemented skip n==0 ---")

for n in range(len(bind)):
    if n == 0:
        print("skips first instance")
        continue
    
    current = bind[n]
    previous = bind[n - 1]

    print(f"n={n}: previous={previous}, current={current}")
