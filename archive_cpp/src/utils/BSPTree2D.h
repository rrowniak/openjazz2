/**********************************************************************************************
//     Copyright 2013 Rafal Rowniak
//     
//     This software is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// 
//     Additional license information:
//     This software can be used and/or modified only for NON-COMMERCIAL purposes.
//
//     Additional information:
//     BSPTree2D.h created 3/29/2013
//
//     Author: Rafal Rowniak
// 
**********************************************************************************************/

#ifndef BSPTREE2D_H
#define BSPTREE2D_H

#include <vector>

template <typename Element, typename PositionGetter>
class BSPTree2D
{
public:

    typedef std::vector<Element> ElementCollection;

    BSPTree2D(const Rectangle2D& worldWindow_, int partitionWidth, int partitionHeight)
    {
        // build the tree
        root = new BSTNode();
        root->x_axis = true;
        root->axis = partitionWidth / 2;
        BuildTree(*root, partitionWidth, partitionHeight, worldWindow_);
    }
    virtual ~BSPTree2D()
    {
        // destroy the tree
        Destroy(root);
    }

    void Insert(const Element& entity)
    {
        PositionGetter f;
        auto* node = Find(f(entity));
        assert(node != nullptr);
        node->AddElement(entity);
    }

    void Insert(Element&& entity)
    {
        PositionGetter f;
        auto* node = Find(f(entity));
        assert(node != nullptr);
        node->AddElement(std::move(entity));
    }

    ElementCollection& GetEntitles(const Point2D& location)
    {
        auto* node = Find(location);
        assert(node != nullptr);
        if (node->leaf == nullptr)
        {
            static ElementCollection empty;
            return empty;
        }
        return node->leaf->values;
    }
private:
    // structures
    struct BSTLeaf
    {
        ElementCollection values;
    };

    struct BSTNode
    {
        bool x_axis;
        int axis;
        BSTNode* child_l = nullptr;
        BSTNode* child_r = nullptr;
        BSTLeaf* leaf = nullptr;

        void AddElement(const Element& e)
        {
            assert(child_l == nullptr);
            assert(child_r == nullptr);
            if (leaf == nullptr)
            {
                leaf = new BSTLeaf();
                // TODO: find optimal value
                leaf->values.reserve(20);
            }
            leaf->values.push_back(e);
        }
        void AddElement(Element&& e)
        {
            assert(child_l == nullptr);
            assert(child_r == nullptr);
            if (leaf == nullptr)
            {
                leaf = new BSTLeaf();
                // TODO: find optimal value
                leaf->values.reserve(20);
            }
            leaf->values.push_back(std::move(e));
        }
    };

    BSTNode* root = nullptr;

    // helpers
    BSTNode* Find(const Point2D& location)
    {
        BSTNode* n = root;

        while (n->child_l != nullptr && n->child_r != nullptr)
        {
            bool left = false;
            if (n->x_axis && location.x < n->axis)
            {
                left = true;
            }
            else if (location.y < n->axis)
            {
                left = true;
            }

            if (left)
            {
                n = n->child_l;
            }
            else
            {
                n = n->child_r;
            }
        }

        return n;
    }

    void BuildTree(BSTNode& root, int minWidth, int minHeight,
                   const Rectangle2D& area)
    {
        int axis = 0;
        Rectangle2D rr, rl;
        if (root.x_axis)
        {
            axis = area.x + area.w / 2;
            rr.y = rl.y = area.y;
            rr.h = rl.h = area.h;
            rl.x = area.x;
            rr.x = area.x + area.w / 2;
            rl.w = rr.w = area.w / 2;
        }
        else
        {
            axis = area.y + area.h / 2;
            rr.x = rl.x = area.x;
            rr.w = rl.w = area.w;
            rl.y = area.y;
            rr.y = area.y + area.h / 2;
            rl.h = rr.h = area.h / 2;
        }

        if (rr.h < minHeight || rr.w < minWidth)
        {
            return;
        }

        root.child_l = new BSTNode();
        root.child_r = new BSTNode();
        root.child_l->x_axis = !root.x_axis;
        root.child_r->x_axis = !root.x_axis;
        root.child_l->axis = axis;
        root.child_r->axis = axis;

        BuildTree(*root.child_l, minWidth, minHeight, rl);
        BuildTree(*root.child_r, minWidth, minHeight, rr);
    }

    // Recurence functions
    void Destroy(BSTNode* node)
    {
        if (node == nullptr)
        {
            return;
        }
        Destroy(node->child_l);
        Destroy(node->child_r);

        delete node->leaf;
        delete node;
    }
};

#endif // BSPTREE2D_H
