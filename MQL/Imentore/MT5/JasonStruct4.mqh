// Update 10
#include <Object.mqh>
#include <Generic/HashMap.mqh>

class OrderJason
{
private:
    CHashMap<string, CObject*> order_jasons;

public:
    ~OrderJason()  // Destructor
    {
        // Delete all CObject objects
        string keys[];
        CObject* values[];
        order_jasons.CopyTo(keys, values);
        for(int i = 0; i < order_jasons.Count(); i++)
        {
            delete values[i];
        }
    }

    void AddOrder(string key, CObject* order)
    {
        order_jasons.Add(key, order);
    }

    void AddValue(string key, string subKey, string value)
    {
        CObject* order;
        if(order_jasons.TryGetValue(key, order))
        {
            order.AddProperty(subKey, value);
        }
    }

    void AddValue(string key, string subKey, int value)
    {
        CObject* order;
        if(order_jasons.TryGetValue(key, order))
        {
            order.AddProperty(subKey, value);
        }
    }

    void AddValue(string key, string subKey, double value)
    {
        CObject* order;
        if(order_jasons.TryGetValue(key, order))
        {
            order.AddProperty(subKey, value);
        }
    }

    string GetStringProperty(string key, string subKey)
    {
        CObject* order;
        if(order_jasons.TryGetValue(key, order))
        {
            return order.GetProperty(subKey);
        }
        return NULL;
    }

    int GetIntProperty(string key, string subKey)
    {
        CObject* order;
        if(order_jasons.TryGetValue(key, order))
        {
            return order.GetProperty(subKey);
        }
        return NULL;
    }

    double GetDoubleProperty(string key, string subKey)
    {
        CObject* order;
        if(order_jasons.TryGetValue(key, order))
        {
            return order.GetProperty(subKey);
        }
        return NULL;
    }
};
